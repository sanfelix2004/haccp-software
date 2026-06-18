import Foundation
import SwiftData
import UIKit
import CryptoKit

/// Generazione automatica dei documenti da registri HACCP (anti-duplicato, backfill, PDF ufficiali).
@MainActor
final class DocumentGenerationService {
    static let shared = DocumentGenerationService()

    private init() {}

    struct GenerationKey: Hashable {
        let type: DocumentType
        let module: DocumentModule
        let periodStart: TimeInterval
    }

    private let maxBackfillDays = 400

    func syncArchive(
        restaurant: Restaurant,
        user: LocalUser,
        receipts: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        traceabilityImages: [ProductImage],
        productions: [Production],
        traceabilityLinks: [TraceabilityLink],
        traceabilityLogs: [TraceabilityLog],
        checklistAuditLogs: [ChecklistAuditLog],
        temperatureAuditLogs: [TemperatureAuditLog],
        modelContext: ModelContext
    ) async {
        await Task.yield()
        let rid = restaurant.id
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current

        let allFolders = (try? modelContext.fetch(FetchDescriptor<DocumentFolder>())) ?? []
        let scopedFolders = allFolders.filter { $0.restaurantId == rid }
        let allItems = (try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? []
        var scopedItems = allItems.filter { $0.restaurantId == rid }
        for it in scopedItems where it.type == .nonConformita {
            it.type = .mensile
        }
        for it in scopedItems where it.officialDocumentId.isEmpty {
            it.officialDocumentId = "HACCP-DOC-\(it.id.uuidString.uppercased())"
        }
        let scopedReceipts = receipts.filter { $0.restaurantId == rid }
        let scopedTrace = traceabilityRecords.filter { $0.restaurantId == rid }
        let scopedProductions = productions.filter { $0.restaurantId == rid }
        let scopedChecklistLogs = checklistAuditLogs.filter { $0.restaurantId == rid }
        let scopedTempLogs = temperatureAuditLogs.filter { $0.restaurantId == rid }

        var keyIndex: [GenerationKey: DocumentItem] = [:]
        for it in scopedItems {
            if let k = makeKey(for: it, calendar: calendar) {
                keyIndex[k] = it
            }
        }

        repairMissingFiles(
            items: scopedItems,
            restaurant: restaurant,
            user: user,
            folders: scopedFolders,
            receipts: scopedReceipts,
            traceability: scopedTrace,
            images: traceabilityImages,
            productions: scopedProductions,
            links: traceabilityLinks,
            logs: traceabilityLogs,
            checklistLogs: scopedChecklistLogs,
            temperatureLogs: scopedTempLogs,
            allDocuments: allItems,
            calendar: calendar,
            modelContext: modelContext,
            keyIndex: &keyIndex
        )

        let todayStart = calendar.startOfDay(for: Date())
        let creationStart = calendar.startOfDay(for: restaurant.creationDate)

        let batchContext = ArchiveBatchContext(
            restaurant: restaurant,
            user: user,
            folders: scopedFolders,
            receipts: scopedReceipts,
            traceability: scopedTrace,
            images: traceabilityImages,
            productions: scopedProductions,
            links: traceabilityLinks,
            logs: traceabilityLogs,
            checklistLogs: scopedChecklistLogs,
            temperatureLogs: scopedTempLogs,
            allDocuments: allItems,
            calendar: calendar,
            modelContext: modelContext
        )

        // Nessuna generazione durante il mese corrente: i report vengono creati solo a mese chiuso.

        // Fine mese: report mensile per ogni modulo + report combinato + registro NC.
        let backfillLimit = calendar.date(byAdding: .day, value: -maxBackfillDays, to: todayStart) ?? creationStart
        let monthLower = max(creationStart, backfillLimit)
        await forEachClosedMonth(from: monthLower, through: Date(), calendar: calendar) { interval in
            await self.generateFullMonthArchive(
                context: batchContext,
                monthInterval: interval,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems
            )
        }

        purgeExpiredTemporaryExports()
        try? modelContext.save()
    }

    func regenerateDocument(
        _ item: DocumentItem,
        restaurant: Restaurant,
        user: LocalUser,
        folders: [DocumentFolder],
        receipts: [GoodsReceipt],
        traceabilityRecords: [TraceabilityRecord],
        traceabilityImages: [ProductImage],
        productions: [Production],
        traceabilityLinks: [TraceabilityLink],
        traceabilityLogs: [TraceabilityLog],
        checklistAuditLogs: [ChecklistAuditLog],
        temperatureAuditLogs: [TemperatureAuditLog],
        allDocumentItems: [DocumentItem],
        modelContext: ModelContext
    ) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current
        guard let interval = intervalForDocument(item, calendar: calendar) else {
            throw DocumentGeneratorError.invalidPeriod
        }
        let rid = restaurant.id
        try writePDF(
            existing: item,
            restaurant: restaurant,
            user: user,
            folders: folders.filter { $0.restaurantId == rid },
            type: effectiveDocType(item),
            module: item.module,
            interval: interval,
            receipts: receipts.filter { $0.restaurantId == rid },
            traceability: traceabilityRecords.filter { $0.restaurantId == rid },
            images: traceabilityImages,
            productions: productions.filter { $0.restaurantId == rid },
            links: traceabilityLinks,
            logs: traceabilityLogs,
            checklistLogs: checklistAuditLogs.filter { $0.restaurantId == rid },
            temperatureLogs: temperatureAuditLogs.filter { $0.restaurantId == rid },
            allDocuments: allDocumentItems,
            calendar: calendar,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    /// Copia in cartella temporanea per condivisione (pulizia automatica dopo 10 giorni).
    func temporaryExportURL(for item: DocumentItem, restaurantId: UUID) throws -> URL {
        let fm = FileManager.default
        guard item.localFilePresent, fm.fileExists(atPath: item.filePath) else {
            throw DocumentGeneratorError.renderFailed
        }
        let base = try tempExportRoot()
        let destDir = base.appendingPathComponent(restaurantId.uuidString, isDirectory: true)
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = destDir.appendingPathComponent("\(stamp)_\(item.fileName)")
        let src = URL(fileURLWithPath: item.filePath)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: src, to: dest)
        return dest
    }

    func purgeExpiredTemporaryExports(maxAgeDays: Int = 10) {
        guard let base = try? tempExportRoot() else { return }
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 3600)
        guard let en = fm.enumerator(at: base, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else { return }
        while let url = en.nextObject() as? URL {
            guard let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  vals.isRegularFile == true,
                  let mod = vals.contentModificationDate,
                  mod < cutoff
            else { continue }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Private

    private func repairMissingFiles(
        items: [DocumentItem],
        restaurant: Restaurant,
        user: LocalUser,
        folders: [DocumentFolder],
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        allDocuments: [DocumentItem],
        calendar: Calendar,
        modelContext: ModelContext,
        keyIndex: inout [GenerationKey: DocumentItem]
    ) {
        let fm = FileManager.default
        for item in items where item.restaurantId == restaurant.id {
            guard item.status == .generato || item.status == .fallito else { continue }
            guard let ps = item.periodStart else { continue }
            guard !isOpenPeriod(type: effectiveDocType(item), periodStart: ps, calendar: calendar) else { continue }
            let pathOk = fm.fileExists(atPath: item.filePath) && item.localFilePresent
            guard !pathOk else { continue }
            guard let interval = intervalForDocument(item, calendar: calendar) else { continue }
            writePDFIgnoringRenderFailure(
                existing: item,
                restaurant: restaurant,
                user: user,
                folders: folders,
                type: effectiveDocType(item),
                module: item.module,
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                images: images,
                productions: productions,
                links: links,
                logs: logs,
                checklistLogs: checklistLogs,
                temperatureLogs: temperatureLogs,
                allDocuments: allDocuments,
                calendar: calendar,
                modelContext: modelContext
            )
            if let k = makeKey(for: item, calendar: calendar) {
                keyIndex[k] = item
            }
        }
    }

    private func generateIfNeeded(
        context: ArchiveBatchContext,
        type: DocumentType,
        module: DocumentModule,
        interval: DateInterval,
        isOpenPeriod: Bool,
        keyIndex: inout [GenerationKey: DocumentItem],
        scopedItems: inout [DocumentItem]
    ) {
        generateIfNeeded(
            restaurant: context.restaurant,
            user: context.user,
            folders: context.folders,
            type: type,
            module: module,
            interval: interval,
            isOpenPeriod: isOpenPeriod,
            keyIndex: &keyIndex,
            scopedItems: &scopedItems,
            receipts: context.receipts,
            traceability: context.traceability,
            images: context.images,
            productions: context.productions,
            links: context.links,
            logs: context.logs,
            checklistLogs: context.checklistLogs,
            temperatureLogs: context.temperatureLogs,
            allDocuments: context.allDocuments,
            calendar: context.calendar,
            modelContext: context.modelContext
        )
    }

    /// A chiusura mese: un report mensile per modulo + report combinato + registro NC.
    private func generateFullMonthArchive(
        context: ArchiveBatchContext,
        monthInterval: DateInterval,
        keyIndex: inout [GenerationKey: DocumentItem],
        scopedItems: inout [DocumentItem]
    ) async {
        var batchStep = 0
        func step() async {
            batchStep += 1
            if batchStep.isMultiple(of: 3) { await Task.yield() }
        }

        for module in DocumentArchiveLayout.monthEndSingleModules {
            generateIfNeeded(
                context: context,
                type: .mensile,
                module: module,
                interval: monthInterval,
                isOpenPeriod: false,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems
            )
            await step()
        }

        for module in DocumentArchiveLayout.monthEndCombinedModules {
            generateIfNeeded(
                context: context,
                type: .mensile,
                module: module,
                interval: monthInterval,
                isOpenPeriod: false,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems
            )
            await step()
        }
    }

    private func forEachClosedMonth(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        body: (DateInterval) async -> Void
    ) async {
        if start > end { return }
        var c = calendar.dateComponents([.year, .month], from: start)
        guard var y = c.year, var m = c.month else { return }
        let endComps = calendar.dateComponents([.year, .month], from: end)
        guard let endY = endComps.year, let endM = endComps.month else { return }

        while y < endY || (y == endY && m <= endM) {
            guard let monthStart = calendar.date(from: DateComponents(year: y, month: m, day: 1)) else { break }
            let isCurrent = calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
            if !isCurrent, let interval = calendar.dateInterval(of: .month, for: monthStart) {
                await body(interval)
            }
            m += 1
            if m > 12 { m = 1; y += 1 }
        }
    }

    private func enumerateWeeks(in monthInterval: DateInterval, calendar: Calendar, body: (DateInterval) -> Void) {
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else { return }
        while weekStart < monthInterval.end {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { break }
            if weekInterval.end > monthInterval.start && weekInterval.start < monthInterval.end {
                body(weekInterval)
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
    }

    private func generateIfNeeded(
        restaurant: Restaurant,
        user: LocalUser,
        folders: [DocumentFolder],
        type: DocumentType,
        module: DocumentModule,
        interval: DateInterval,
        isOpenPeriod: Bool,
        keyIndex: inout [GenerationKey: DocumentItem],
        scopedItems: inout [DocumentItem],
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        allDocuments: [DocumentItem],
        calendar: Calendar,
        modelContext: ModelContext
    ) {
        let periodStart = normalizedPeriodStart(interval.start, type: type, calendar: calendar)
        let key = GenerationKey(type: type, module: module, periodStart: periodStart.timeIntervalSince1970)
        let fm = FileManager.default

        if !isOpenPeriod, let existing = keyIndex[key], fm.fileExists(atPath: existing.filePath), existing.localFilePresent {
            return
        }

        if let existing = keyIndex[key] {
            writePDFIgnoringRenderFailure(
                existing: existing,
                restaurant: restaurant,
                user: user,
                folders: folders,
                type: type,
                module: module,
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                images: images,
                productions: productions,
                links: links,
                logs: logs,
                checklistLogs: checklistLogs,
                temperatureLogs: temperatureLogs,
                allDocuments: allDocuments,
                calendar: calendar,
                modelContext: modelContext
            )
            return
        }

        guard let folderId = resolveFolderId(
            restaurant: restaurant,
            type: type,
            module: module,
            folders: folders
        ) else { return }

        let fileName = LocalDocumentStorageService.officialFileName(
            restaurantShortName: restaurant.name,
            type: type,
            module: module,
            interval: interval,
            calendar: calendar
        )
        guard let dir = try? LocalDocumentStorageService.shared.stablePDFDirectory(restaurantId: restaurant.id) else { return }
        let fileURL = dir.appendingPathComponent(fileName)

        let newItem = DocumentItem(
            restaurantId: restaurant.id,
            folderId: folderId,
            title: makeReportHeading(type: type, module: module, interval: interval, calendar: calendar),
            fileName: fileName,
            type: type,
            module: module,
            periodStart: interval.start,
            periodEnd: interval.end.addingTimeInterval(-1),
            generatedAt: Date(),
            filePath: fileURL.path,
            format: .pdf,
            status: .generato,
            isExported: false,
            exportedAt: nil,
            sizeInBytes: 0,
            createdByUserId: user.id,
            createdByNameSnapshot: user.name
        )
        modelContext.insert(newItem)
        scopedItems.append(newItem)
        keyIndex[key] = newItem

        writePDFIgnoringRenderFailure(
            existing: newItem,
            restaurant: restaurant,
            user: user,
            folders: folders,
            type: type,
            module: module,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            images: images,
            productions: productions,
            links: links,
            logs: logs,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            allDocuments: allDocuments,
            calendar: calendar,
            modelContext: modelContext
        )
    }

    private func writePDF(
        existing: DocumentItem,
        restaurant: Restaurant,
        user _: LocalUser,
        folders _: [DocumentFolder],
        type: DocumentType,
        module: DocumentModule,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        allDocuments: [DocumentItem],
        calendar: Calendar,
        modelContext: ModelContext
    ) throws {
        let fm = FileManager.default
        let generatedAt = Date()
        if existing.officialDocumentId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existing.officialDocumentId = "HACCP-DOC-\(existing.id.uuidString.uppercased())"
        }

        let officialName = LocalDocumentStorageService.officialFileName(
            restaurantShortName: restaurant.name,
            type: type,
            module: module,
            interval: interval,
            calendar: calendar
        )
        let dir = try LocalDocumentStorageService.shared.stablePDFDirectory(restaurantId: restaurant.id)
        let targetURL = dir.appendingPathComponent(officialName)
        if existing.filePath != targetURL.path {
            if fm.fileExists(atPath: existing.filePath) {
                try? fm.removeItem(atPath: existing.filePath)
            }
            existing.filePath = targetURL.path
            existing.fileName = officialName
        } else if existing.fileName != officialName {
            existing.fileName = officialName
        }

        let periodLine = HACCPRegisterPDFContentFactory.periodLine(interval: interval, calendar: calendar)
        let heading = makeReportHeading(type: type, module: module, interval: interval, calendar: calendar)
        let reportDateLine = reportDateLine(type: type, interval: interval, calendar: calendar)
        let officialId = existing.officialDocumentId
        let docsForRestaurant = allDocuments.filter { $0.restaurantId == restaurant.id }
        let operational = fetchOperationalSource(in: modelContext, restaurantId: restaurant.id)

        var builtPayload: HACCPPDFSectionBundle?
        if type == .mensile, DocumentArchiveLayout.isSingleModule(module) {
            builtPayload = HACCPRegisterPDFContentFactory.buildSingoloModulo(
                documentType: type,
                module: module,
                restaurant: restaurant,
                reportTitle: heading,
                reportDateLine: reportDateLine,
                periodLine: periodLine,
                officialDocumentId: officialId,
                generatedAt: generatedAt,
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                checklistLogs: checklistLogs,
                temperatureLogs: temperatureLogs,
                operational: operational
            )
        } else {
            switch (type, module) {
            case (.mensile, .haccpCombinato):
                builtPayload = HACCPRegisterPDFContentFactory.buildMensileCombinatoUfficiale(
                    restaurant: restaurant,
                    reportTitle: heading,
                    reportDateLine: reportDateLine,
                    periodLine: periodLine,
                    officialDocumentId: officialId,
                    generatedAt: generatedAt,
                    interval: interval,
                    calendar: calendar,
                    receipts: receipts,
                    traceability: traceability,
                    productions: productions,
                    links: links,
                    logs: logs,
                    images: images,
                    checklistLogs: checklistLogs,
                    temperatureLogs: temperatureLogs,
                    existingDocuments: docsForRestaurant,
                    operational: operational
                )
            case (.mensile, .nonConformita):
                builtPayload = HACCPRegisterPDFContentFactory.buildRegistroNonConformitaMensile(
                    restaurant: restaurant,
                    reportTitle: heading,
                    reportDateLine: reportDateLine,
                    periodLine: periodLine,
                    officialDocumentId: officialId,
                    generatedAt: generatedAt,
                    interval: interval,
                    receipts: receipts,
                    traceability: traceability,
                    images: images,
                    checklistLogs: checklistLogs,
                    temperatureLogs: temperatureLogs,
                    logs: logs
                )
            case (.mensile, let combined) where DocumentArchiveLayout.isAffinityCombined(combined):
                builtPayload = HACCPRegisterPDFContentFactory.buildMensileAffinityCombined(
                    combinedModule: combined,
                    restaurant: restaurant,
                    reportTitle: heading,
                    reportDateLine: reportDateLine,
                    periodLine: periodLine,
                    officialDocumentId: officialId,
                    generatedAt: generatedAt,
                    interval: interval,
                    receipts: receipts,
                    traceability: traceability,
                    productions: productions,
                    links: links,
                    logs: logs,
                    images: images,
                    checklistLogs: checklistLogs,
                    temperatureLogs: temperatureLogs,
                    operational: operational
                )
            default:
                builtPayload = nil
            }
        }

        guard let built = builtPayload else {
            existing.status = .fallito
            throw DocumentGeneratorError.renderFailed
        }

        if let flavor = DocumentCompletenessValidator.reportFlavor(type: type, module: module) {
            do {
                try DocumentCompletenessValidator.validate(present: built.flags, flavor: flavor)
            } catch {
                existing.status = .fallito
                throw error
            }
        }

        let pdfContext = HACCPPDFDocumentContext(
            restaurantName: restaurant.name,
            reportTitle: heading,
            periodLine: periodLine,
            reportDateLine: reportDateLine,
            officialDocumentId: officialId,
            generatedAt: generatedAt,
            haccpManager: restaurant.haccpManager,
            restaurantAddress: [restaurant.address, restaurant.city].filter { !$0.isEmpty }.joined(separator: ", "),
            restaurantContacts: [restaurant.phone, restaurant.email].filter { !$0.isEmpty }.joined(separator: " · ")
        )

        guard let rawPDF = HACCPDocumentPDFRenderer.render(
            context: pdfContext,
            sections: built.sections,
            omitBuiltInFooter: true,
            bodyFontSize: 9.2
        ) else {
            existing.status = .fallito
            throw DocumentGeneratorError.renderFailed
        }

        guard let stamped = HACCPPDFOfficialFooterStamper.stamp(
            data: rawPDF,
            generatedAt: generatedAt,
            officialDocumentId: officialId
        ) else {
            existing.status = .fallito
            throw DocumentGeneratorError.renderFailed
        }

        let checksum = Self.sha256Hex(stamped)
        let parent = targetURL.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try stamped.write(to: targetURL, options: .atomic)

        existing.title = heading
        existing.generatedAt = generatedAt
        existing.sizeInBytes = Int64(stamped.count)
        existing.periodStart = interval.start
        existing.periodEnd = interval.end.addingTimeInterval(-1)
        existing.status = .generato
        existing.format = .pdf
        existing.checksumSHA256 = checksum
        existing.documentBuildVersion = HACCPAppBuildVersion.marketingAndBuild
        existing.localFilePresent = true
        existing.iCloudRelativePath = LocalDocumentStorageService.shared.relativePathForICloud(
            restaurantDisplayName: restaurant.name,
            periodFolder: LocalDocumentStorageService.periodFolderLabel(type: type),
            fileName: officialName
        )

        existing.isSyncedToICloud = false
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func reportDateLine(type: DocumentType, interval: DateInterval, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        switch type {
        case .giornaliero:
            df.dateFormat = "d MMMM yyyy"
            return df.string(from: interval.start)
        case .settimanale:
            let end = interval.end.addingTimeInterval(-1)
            df.dateFormat = "d MMM yyyy"
            return "Settimana \(df.string(from: interval.start)) - \(df.string(from: end))"
        case .mensile, .nonConformita:
            df.dateFormat = "MMMM yyyy"
            return df.string(from: interval.start).capitalized
        case .annuale:
            return "\(calendar.component(.year, from: interval.start))"
        default:
            df.dateStyle = .long
            df.timeStyle = .none
            return df.string(from: interval.start)
        }
    }

    /// Normalizza tipi legacy (es. registro NC con `type == .nonConformita`) al mensile.
    private func effectiveDocType(_ item: DocumentItem) -> DocumentType {
        if item.type == .nonConformita || item.module == .nonConformita {
            return .mensile
        }
        return item.type
    }

    private func makeKey(for item: DocumentItem, calendar: Calendar) -> GenerationKey? {
        guard let ps = item.periodStart else { return nil }
        let t = effectiveDocType(item)
        let n = normalizedPeriodStart(ps, type: t, calendar: calendar)
        return GenerationKey(type: t, module: item.module, periodStart: n.timeIntervalSince1970)
    }

    private func normalizedPeriodStart(_ date: Date, type: DocumentType, calendar: Calendar) -> Date {
        switch type {
        case .giornaliero:
            return calendar.startOfDay(for: date)
        case .settimanale:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .mensile, .nonConformita:
            let c = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: c) ?? calendar.startOfDay(for: date)
        case .annuale:
            let y = calendar.component(.year, from: date)
            return calendar.date(from: DateComponents(year: y, month: 1, day: 1)) ?? date
        default:
            return calendar.startOfDay(for: date)
        }
    }

    private func isOpenPeriod(type: DocumentType, periodStart: Date, calendar: Calendar) -> Bool {
        let now = Date()
        switch type {
        case .giornaliero:
            return calendar.isDate(periodStart, inSameDayAs: now)
        case .settimanale:
            return calendar.isDate(periodStart, equalTo: now, toGranularity: .weekOfYear)
        case .mensile, .nonConformita:
            let c1 = calendar.dateComponents([.year, .month], from: periodStart)
            let c2 = calendar.dateComponents([.year, .month], from: now)
            return c1.year == c2.year && c1.month == c2.month
        case .annuale:
            return calendar.component(.year, from: periodStart) == calendar.component(.year, from: now)
        default:
            return false
        }
    }

    private func intervalForDocument(_ item: DocumentItem, calendar: Calendar) -> DateInterval? {
        guard let start = item.periodStart else { return nil }
        switch effectiveDocType(item) {
        case .giornaliero:
            return dayInterval(containing: start, calendar: calendar)
        case .settimanale:
            return calendar.dateInterval(of: .weekOfYear, for: start)
        case .mensile, .nonConformita:
            return calendar.dateInterval(of: .month, for: start)
        case .annuale:
            return calendar.dateInterval(of: .year, for: start)
        default:
            return dayInterval(containing: start, calendar: calendar)
        }
    }

    private func dayInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return DateInterval(start: start, end: end)
    }

    private func enumerateMonths(from start: Date, through end: Date, calendar: Calendar, body: (Date, Bool) -> Void) {
        if start > end { return }
        var c = calendar.dateComponents([.year, .month], from: start)
        guard let ys = c.year, let ms = c.month else { return }
        var y = ys
        var m = ms
        let endComps = calendar.dateComponents([.year, .month], from: end)
        guard let endY = endComps.year, let endM = endComps.month else { return }
        guard ys < endY || (ys == endY && ms <= endM) else { return }

        while y < endY || (y == endY && m <= endM) {
            guard let monthStart = calendar.date(from: DateComponents(year: y, month: m, day: 1)) else { break }
            let isCurrent = calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
            body(monthStart, isCurrent)
            m += 1
            if m > 12 { m = 1; y += 1 }
        }
    }

    private func enumerateYears(from start: Date, through end: Date, calendar: Calendar, body: (Date, Bool) -> Void) {
        let y0 = calendar.component(.year, from: start)
        let y1 = calendar.component(.year, from: end)
        guard y0 <= y1 else { return }
        for y in y0...y1 {
            guard let yearStart = calendar.date(from: DateComponents(year: y, month: 1, day: 1)) else { continue }
            let isCurrent = calendar.component(.year, from: Date()) == y
            body(yearStart, isCurrent)
        }
    }

    private func resolveFolderId(
        restaurant: Restaurant,
        type: DocumentType,
        module: DocumentModule,
        folders: [DocumentFolder]
    ) -> UUID? {
        let venueName = DocumentArchiveLayout.venueFolderName(for: restaurant)
        let periodRoot = DocumentArchiveLayout.monthlyPeriodName

        guard let venue = folders.first(where: {
            $0.restaurantId == restaurant.id && $0.parentId == nil && $0.name == venueName
        }) else {
            return nil
        }

        guard let mensili = folders.first(where: {
            $0.restaurantId == restaurant.id && $0.parentId == venue.id && $0.name == periodRoot
        }) else {
            return nil
        }

        let moduleTitle = DocumentArchiveLayout.moduleFolderTitle(module)
        let groupName = DocumentArchiveLayout.groupFolderName(for: module)

        if let group = folders.first(where: { $0.parentId == mensili.id && $0.name == groupName }),
           let leaf = folders.first(where: { $0.parentId == group.id && $0.name == moduleTitle }) {
            return leaf.id
        }

        return folders.first(where: { $0.parentId == mensili.id && $0.name == moduleTitle })?.id
    }

    private func fetchOperationalSource(in modelContext: ModelContext, restaurantId: UUID) -> HACCPOperationalSourceData {
        func scoped<T>(_ descriptor: FetchDescriptor<T>, filter: (T) -> Bool) -> [T] {
            ((try? modelContext.fetch(descriptor)) ?? []).filter(filter)
        }

        let temperatureRecords = scoped(FetchDescriptor<TemperatureRecord>(), filter: { $0.restaurantId == restaurantId })
        let cleaningRecords = scoped(FetchDescriptor<CleaningRecord>(), filter: { $0.restaurantId == restaurantId })
        let defrostRecords = scoped(FetchDescriptor<DefrostRecord>(), filter: { $0.restaurantId == restaurantId })
        let blastChillingRecords = scoped(FetchDescriptor<BlastChillingRecord>(), filter: { $0.restaurantId == restaurantId })
        let oilControlRecords = scoped(FetchDescriptor<OilControlRecord>(), filter: { $0.restaurantId == restaurantId })
        let checklistRuns = scoped(FetchDescriptor<ChecklistRun>(), filter: { $0.restaurantId == restaurantId })
        let checklistItemResults = (try? modelContext.fetch(FetchDescriptor<ChecklistItemResult>())) ?? []
        let productionLabels = scoped(FetchDescriptor<ProductionLabelRecord>(), filter: { $0.restaurantId == restaurantId })

        return HACCPOperationalSourceData(
            temperatureRecords: temperatureRecords,
            cleaningRecords: cleaningRecords,
            defrostRecords: defrostRecords,
            blastChillingRecords: blastChillingRecords,
            oilControlRecords: oilControlRecords,
            checklistRuns: checklistRuns,
            checklistItemResults: checklistItemResults,
            productionLabels: productionLabels
        )
    }

    private func makeReportHeading(type: DocumentType, module: DocumentModule, interval: DateInterval, calendar: Calendar) -> String {
        let moduleLabel = DocumentArchiveLayout.moduleFolderTitle(module)
        let periodShort = periodShortLabel(type: type, interval: interval, calendar: calendar)
        let typeLabel = registerTypeLabel(type)
        return "\(typeLabel) — \(moduleLabel) — \(periodShort)"
    }

    private func periodShortLabel(type: DocumentType, interval: DateInterval, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        switch type {
        case .giornaliero:
            df.dateFormat = "d MMMM yyyy"
            return df.string(from: interval.start)
        case .settimanale:
            let end = interval.end.addingTimeInterval(-1)
            df.dateFormat = "d MMM"
            return "\(df.string(from: interval.start)) - \(df.string(from: end))"
        case .mensile:
            df.dateFormat = "MMMM yyyy"
            return df.string(from: interval.start).capitalized
        case .annuale:
            return "\(calendar.component(.year, from: interval.start))"
        default:
            return df.string(from: interval.start)
        }
    }

    private func writePDFIgnoringRenderFailure(
        existing: DocumentItem,
        restaurant: Restaurant,
        user: LocalUser,
        folders: [DocumentFolder],
        type: DocumentType,
        module: DocumentModule,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        allDocuments: [DocumentItem],
        calendar: Calendar,
        modelContext: ModelContext
    ) {
        let fm = FileManager.default
        do {
            try writePDF(
                existing: existing,
                restaurant: restaurant,
                user: user,
                folders: folders,
                type: type,
                module: module,
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                images: images,
                productions: productions,
                links: links,
                logs: logs,
                checklistLogs: checklistLogs,
                temperatureLogs: temperatureLogs,
                allDocuments: allDocuments,
                calendar: calendar,
                modelContext: modelContext
            )
        } catch {
            existing.status = .fallito
            if fm.fileExists(atPath: existing.filePath) {
                try? fm.removeItem(atPath: existing.filePath)
            }
            existing.localFilePresent = false
            existing.checksumSHA256 = ""
        }
    }

    private func periodRootName(for _: DocumentType) -> String {
        "Mensili"
    }

    private func registerTypeLabel(_ type: DocumentType) -> String {
        switch type {
        case .giornaliero: return "Registro giornaliero"
        case .settimanale: return "Registro settimanale"
        case .mensile: return "Registro mensile"
        case .annuale: return "Registro annuale"
        case .nonConformita: return "Registro non conformità"
        default: return "Registro"
        }
    }

    private func tempExportRoot() throws -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HACCPDocumentiEsportazioneTemp", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

/// Alias per compatibilità con chiamate esistenti al servizio di generazione documenti.
typealias DocumentGeneratorService = DocumentGenerationService

private struct ArchiveBatchContext {
    let restaurant: Restaurant
    let user: LocalUser
    let folders: [DocumentFolder]
    let receipts: [GoodsReceipt]
    let traceability: [TraceabilityRecord]
    let images: [ProductImage]
    let productions: [Production]
    let links: [TraceabilityLink]
    let logs: [TraceabilityLog]
    let checklistLogs: [ChecklistAuditLog]
    let temperatureLogs: [TemperatureAuditLog]
    let allDocuments: [DocumentItem]
    let calendar: Calendar
    let modelContext: ModelContext
}

enum DocumentGeneratorError: Error {
    case invalidPeriod
    case renderFailed
}
