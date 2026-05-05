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
    ) {
        let rid = restaurant.id
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "it_IT")
        calendar.timeZone = .current

        let allFolders = (try? modelContext.fetch(FetchDescriptor<DocumentFolder>())) ?? []
        let scopedFolders = allFolders.filter { $0.restaurantId == rid }
        let allItems = (try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? []
        var scopedItems = allItems.filter { $0.restaurantId == rid }
        for it in scopedItems where it.type == .mensile && it.module == .nonConformita {
            it.type = .nonConformita
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
        let backfillLimit = calendar.date(byAdding: .day, value: -maxBackfillDays, to: todayStart) ?? creationStart
        let dailyLower = max(creationStart, backfillLimit)

        // Giornalieri (chiusi)
        var dayCursor = dailyLower
        while dayCursor < todayStart {
            let interval = dayInterval(containing: dayCursor, calendar: calendar)
            for module in DocumentArchiveLayout.dailyModules {
                generateIfNeeded(
                    restaurant: restaurant,
                    user: user,
                    folders: scopedFolders,
                    type: .giornaliero,
                    module: module,
                    interval: interval,
                    isOpenPeriod: false,
                    keyIndex: &keyIndex,
                    scopedItems: &scopedItems,
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
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = next
        }

        // Giornalieri (oggi, sempre aggiornati)
        let todayInterval = dayInterval(containing: todayStart, calendar: calendar)
        for module in DocumentArchiveLayout.dailyModules {
            generateIfNeeded(
                restaurant: restaurant,
                user: user,
                folders: scopedFolders,
                type: .giornaliero,
                module: module,
                interval: todayInterval,
                isOpenPeriod: true,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems,
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
        }

        // Settimanali (solo settimane chiuse)
        enumerateWeeks(from: creationStart, through: Date(), calendar: calendar) { weekStart, isCurrentWeek in
            guard !isCurrentWeek,
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { return }
            for module in DocumentArchiveLayout.weeklyModules {
                generateIfNeeded(
                    restaurant: restaurant,
                    user: user,
                    folders: scopedFolders,
                    type: .settimanale,
                    module: module,
                    interval: interval,
                    isOpenPeriod: false,
                    keyIndex: &keyIndex,
                    scopedItems: &scopedItems,
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
            }
        }

        // Mensili ricezione/tracciabilità/combinato + non conformità (solo mesi chiusi)
        enumerateMonths(from: creationStart, through: Date(), calendar: calendar) { monthStart, isCurrentMonth in
            guard !isCurrentMonth else { return }
            guard let interval = calendar.dateInterval(of: .month, for: monthStart) else { return }
            for module in DocumentArchiveLayout.monthlyModules {
                generateIfNeeded(
                    restaurant: restaurant,
                    user: user,
                    folders: scopedFolders,
                    type: .mensile,
                    module: module,
                    interval: interval,
                    isOpenPeriod: false,
                    keyIndex: &keyIndex,
                    scopedItems: &scopedItems,
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
            }
            generateIfNeeded(
                restaurant: restaurant,
                user: user,
                folders: scopedFolders,
                type: .nonConformita,
                module: .nonConformita,
                interval: interval,
                isOpenPeriod: false,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems,
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
        }

        // Annuali — solo combinato (solo anni chiusi)
        enumerateYears(from: creationStart, through: Date(), calendar: calendar) { yearStart, isCurrentYear in
            guard !isCurrentYear else { return }
            guard let interval = calendar.dateInterval(of: .year, for: yearStart) else { return }
            generateIfNeeded(
                restaurant: restaurant,
                user: user,
                folders: scopedFolders,
                type: .annuale,
                module: .haccpCombinato,
                interval: interval,
                isOpenPeriod: false,
                keyIndex: &keyIndex,
                scopedItems: &scopedItems,
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
            restaurantId: restaurant.id,
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

        var builtPayload: (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags)?
        switch (type, module) {
        case (.giornaliero, .haccpCombinato):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroCombinatoUfficiale(
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
                temperatureLogs: temperatureLogs
            )
        case (.giornaliero, .ricezioneMerci):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroRicezione,
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
                temperatureLogs: temperatureLogs
            )
        case (.giornaliero, .tracciabilita):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroTracciabilita,
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
                temperatureLogs: temperatureLogs
            )
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
                existingDocuments: docsForRestaurant
            )
        case (.mensile, .ricezioneMerci):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroRicezione,
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
                temperatureLogs: temperatureLogs
            )
        case (.mensile, .tracciabilita):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroTracciabilita,
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
                temperatureLogs: temperatureLogs
            )
        case (.settimanale, .haccpCombinato):
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
                existingDocuments: docsForRestaurant
            )
        case (.settimanale, .ricezioneMerci):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroRicezione,
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
                temperatureLogs: temperatureLogs
            )
        case (.settimanale, .tracciabilita):
            builtPayload = HACCPRegisterPDFContentFactory.buildGiornalieroModulo(
                flavor: .giornalieroTracciabilita,
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
                temperatureLogs: temperatureLogs
            )
        case (.annuale, .haccpCombinato):
            builtPayload = HACCPRegisterPDFContentFactory.buildAnnualeCombinatoUfficiale(
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
                existingDocuments: docsForRestaurant
            )
        case (.nonConformita, _):
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
        default:
            builtPayload = nil
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

        guard let rawPDF = HACCPDocumentPDFRenderer.render(
            restaurantName: restaurant.name,
            reportTitle: heading,
            periodLine: periodLine,
            generatedAt: generatedAt,
            sections: built.sections,
            omitBuiltInFooter: true,
            bodyFontSize: 8.4
        ) else {
            existing.status = .fallito
            throw DocumentGeneratorError.renderFailed
        }

        guard let stamped = HACCPPDFOfficialFooterStamper.stamp(data: rawPDF, generatedAt: generatedAt) else {
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

    /// Documenti mensili «non conformità» legacy usavano `type == .mensile`; la chiave e la generazione usano `.nonConformita`.
    private func effectiveDocType(_ item: DocumentItem) -> DocumentType {
        if item.type == .mensile && item.module == .nonConformita { return .nonConformita }
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

    private func enumerateWeeks(from start: Date, through end: Date, calendar: Calendar, body: (Date, Bool) -> Void) {
        guard start <= end else { return }
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { return }
        while weekStart <= end {
            let isCurrent = calendar.isDate(weekStart, equalTo: end, toGranularity: .weekOfYear)
            body(weekStart, isCurrent)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
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
        restaurantId: UUID,
        type: DocumentType,
        module: DocumentModule,
        folders: [DocumentFolder]
    ) -> UUID? {
        let periodRoot = periodRootName(for: type)

        guard let root = folders.first(where: { $0.restaurantId == restaurantId && $0.parentId == nil && $0.name == periodRoot }) else {
            return nil
        }

        if type == .annuale {
            guard let child = folders.first(where: { $0.parentId == root.id && $0.name == "HACCP combinato" }) else { return nil }
            return child.id
        }

        if type == .nonConformita || module == .nonConformita {
            return folders.first(where: { $0.restaurantId == restaurantId && $0.parentId == nil && $0.name == "Non conformità" })?.id
        }

        let moduleTitle = DocumentArchiveLayout.moduleFolderTitle(module)
        return folders.first(where: { $0.parentId == root.id && $0.name == moduleTitle })?.id
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

    private func periodRootName(for type: DocumentType) -> String {
        switch type {
        case .giornaliero: return "Giornalieri"
        case .settimanale: return "Settimanali"
        case .mensile: return "Mensili"
        case .annuale: return "Annuali"
        default: return "Giornalieri"
        }
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

enum DocumentArchiveLayout {
    static let dailyModules: [DocumentModule] = [.ricezioneMerci, .tracciabilita, .haccpCombinato]
    static let weeklyModules: [DocumentModule] = dailyModules
    static let monthlyModules: [DocumentModule] = dailyModules

    static func moduleFolderTitle(_ module: DocumentModule) -> String {
        switch module {
        case .ricezioneMerci: return "Ricezione merci"
        case .tracciabilita: return "Tracciabilità"
        case .haccpCombinato: return "HACCP combinato"
        case .nonConformita: return "Non conformità"
        default: return module.label
        }
    }
}

enum DocumentGeneratorError: Error {
    case invalidPeriod
    case renderFailed
}
