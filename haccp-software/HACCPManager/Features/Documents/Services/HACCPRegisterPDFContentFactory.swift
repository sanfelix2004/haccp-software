import Foundation

/// Costruisce le sezioni PDF ufficiali dai registri SwiftData (dati reali).
enum HACCPRegisterPDFContentFactory {
    private static func df() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private static func dayOnly() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM yyyy"
        return f
    }

    static func periodLine(interval: DateInterval, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .medium
        f.timeStyle = .none
        let endInclusive = interval.end.addingTimeInterval(-1)
        return "\(f.string(from: interval.start)) → \(f.string(from: endInclusive))"
    }

    private static func img(_ data: Data?) -> PDFTableCell {
        .image(HACCPPDFImageCompression.compressedJPEGData(from: data) ?? data)
    }

    // MARK: - Intestazione

    static func sectionIntestazioneUfficiale(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date
    ) -> (title: String, headers: [String], rows: [[PDFTableCell]]) {
        let df = df()
        let addr = [restaurant.address, restaurant.city].filter { !$0.isEmpty }.joined(separator: ", ")
        let rows: [[PDFTableCell]] = [
            [.text("Ristorante"), .text(restaurant.name)],
            [.text("Indirizzo"), .text(addr.isEmpty ? "—" : addr)],
            [.text("Responsabile HACCP"), .text(restaurant.haccpManager.isEmpty ? "—" : restaurant.haccpManager)],
            [.text("Titolo report"), .text(reportTitle)],
            [.text("Data report"), .text(reportDateLine)],
            [.text("Periodo coperto"), .text(periodLine)],
            [.text("Data/ora generazione"), .text(df.string(from: generatedAt))],
            [.text("Versione app"), .text(HACCPAppBuildVersion.marketingAndBuild)],
            [.text("ID documento"), .text(officialDocumentId)]
        ]
        return ("Intestazione documento ufficiale", ["Campo", "Valore"], rows)
    }

    static func sectionLogoIfPresent(logoData: Data?) -> (title: String, headers: [String], rows: [[PDFTableCell]])? {
        guard let logoData, !logoData.isEmpty else { return nil }
        return ("Logo ristorante", ["Anteprima"], [[img(logoData)]])
    }

    // MARK: - Ricezione / Tracciabilità / NC

    static func sectionsRicezione(interval: DateInterval, receipts: [GoodsReceipt]) -> [(title: String, headers: [String], rows: [[PDFTableCell]])] {
        let formatter = df()
        let rows = GoodsReceiptRegister.rows(in: interval, receipts: receipts, df: formatter)
        let table: [[PDFTableCell]] = rows.map { r in
            [
                .text(r.product),
                .text(r.category),
                .text(r.supplier),
                .text(r.lot),
                .text(r.expiry),
                .text(r.receivedAt),
                .text(r.temperatureRead),
                .text(r.temperatureRange),
                .text(r.temperatureOutcome),
                .text(r.checklist),
                .text(r.conformity),
                .text(r.notes),
                .text(r.operatorName),
                img(r.imageData)
            ]
        }
        let headers = [
            "Prodotto", "Categoria", "Fornitore", "Lotto", "Scadenza", "Data/ora ricezione",
            "Temp. rilevata", "Range temp.", "Esito temp.", "Checklist", "Conformità", "Note", "Operatore", "Foto"
        ]
        return [("A. Ricezione merci", headers, table)]
    }

    static func sectionsTracciabilita(
        interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage]
    ) -> [(title: String, headers: [String], rows: [[PDFTableCell]])] {
        let formatter = df()
        let rows = TraceabilityRegister.rows(
            in: interval,
            records: records,
            productions: productions,
            links: links,
            logs: logs,
            images: images,
            df: formatter
        )
        let table: [[PDFTableCell]] = rows.map { r in
            [
                .text(r.product),
                .text(r.lot),
                .text(r.supplier),
                .text(r.receivedAt),
                .text(r.status),
                .text(r.productions),
                .text(r.nonCompliance),
                .text(r.events),
                .text(r.eventTimestamps),
                img(r.eventImageData),
                .text(r.operatorName),
                img(r.productImageData)
            ]
        }
        let headers = [
            "Prodotto", "Lotto", "Fornitore", "Data ricezione", "Stato prodotto",
            "Produzioni associate", "Non conformità", "Eventi", "Timestamp eventi",
            "Foto evento", "Operatore", "Foto prodotto"
        ]
        return [("B. Tracciabilità", headers, table)]
    }

    static func sectionsNonConformita(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage]
    ) -> [(title: String, headers: [String], rows: [[PDFTableCell]])] {
        let formatter = df()
        let rows = NonConformityRegister.rows(
            in: interval,
            receipts: receipts,
            traceability: traceability,
            images: images,
            df: formatter
        )
        let table: [[PDFTableCell]] = rows.map { r in
            [
                .text(r.product),
                .text(r.lot),
                .text(r.reason),
                .text(r.correctiveAction),
                img(r.imageData),
                .text(r.stato),
                .text(r.risoltaDa),
                .text(r.risoltaIl),
                .text(r.date),
                .text(r.operatorName),
                .text(r.source)
            ]
        }
        let headers = [
            "Prodotto", "Lotto", "Motivo", "Azione correttiva", "Foto",
            "Stato", "Risolta da", "Risolta il", "Data rilevazione", "Operatore", "Origine"
        ]
        return [("C. Non conformità", headers, table)]
    }

    // MARK: - Audit

    static func sectionAudit(
        restaurantId: UUID,
        interval: DateInterval,
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        traceabilityRecordIds: Set<UUID>
    ) -> (title: String, headers: [String], rows: [[PDFTableCell]]) {
        let formatter = df()
        let audit = HACCPDocumentAuditLogBuilder.rows(
            restaurantId: restaurantId,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: traceabilityLogs,
            traceabilityRecordIds: traceabilityRecordIds,
            df: formatter
        )
        let rows: [[PDFTableCell]] = audit.map { r in
            [.text(r.userName), .text(r.module), .text(r.timestamp), .text(r.action), .text(r.entityRef)]
        }
        return ("D. Audit log (azioni registrate)", ["Utente", "Modulo", "Data/ora", "Azione", "Entità collegata"], rows)
    }

    // MARK: - Riepilogo

    static func sectionRiepilogo(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        links: [TraceabilityLink]
    ) -> (title: String, headers: [String], rows: [[PDFTableCell]]) {
        let rec = receipts.filter { interval.contains($0.receivedAt) }
        let tr = traceability.filter { interval.contains($0.receivedAt) }
        let ncCount = NonConformityRegister.rows(
            in: interval,
            receipts: receipts,
            traceability: traceability,
            images: [],
            df: df()
        ).count
        let expired = tr.filter { $0.productStatus == .expired }.count
        let linkedIds = Set(links.map(\.receivedItemId))
        let withProd = tr.filter { linkedIds.contains($0.id) }.count

        let rows: [[PDFTableCell]] = [
            [.text("Numero ricezioni nel periodo"), .text("\(rec.count)")],
            [.text("Numero prodotti tracciati (record)"), .text("\(tr.count)")],
            [.text("Numero non conformità"), .text("\(ncCount)")],
            [.text("Numero prodotti in stato scaduto"), .text("\(expired)")],
            [.text("Numero prodotti associati a produzioni"), .text("\(withProd)")],
            [.text("Note finali"), .text("Dati calcolati su registrazioni effettive in app. Archivio ufficiale HACCP Manager.")]
        ]
        return ("E. Riepilogo finale", ["Indicatore", "Valore"], rows)
    }

    // MARK: - Giornaliero combinato ufficiale

    static func buildGiornalieroCombinatoUfficiale(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog]
    ) -> (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags) {
        var flags: OfficialReportSectionFlags = []
        var sections: [(title: String, headers: [String], rows: [[PDFTableCell]])] = []

        let head = sectionIntestazioneUfficiale(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt
        )
        sections.append(head)
        flags.insert(.intestazione)

        if let logo = sectionLogoIfPresent(logoData: restaurant.logoData) {
            sections.append(logo)
        }

        sections.append(contentsOf: sectionsRicezione(interval: interval, receipts: receipts))
        flags.insert(.ricezioneMerci)

        sections.append(contentsOf: sectionsTracciabilita(
            interval: interval,
            records: traceability,
            productions: productions,
            links: links,
            logs: logs,
            images: images
        ))
        flags.insert(.tracciabilita)

        sections.append(contentsOf: sectionsNonConformita(
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            images: images
        ))
        flags.insert(.nonConformita)

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)

        sections.append(sectionRiepilogo(interval: interval, receipts: receipts, traceability: traceability, links: links))
        flags.insert(.riepilogo)

        return (sections, flags)
    }

    // MARK: - Mensile / annuale combinato

    static func buildMensileCombinatoUfficiale(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        interval: DateInterval,
        calendar: Calendar,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        existingDocuments: [DocumentItem]
    ) -> (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags) {
        var base = buildGiornalieroCombinatoUfficiale(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
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
        var flags = base.flags
        var sections = base.sections

        let dailyBreakdown = dailyBreakdownRows(interval: interval, calendar: calendar, receipts: receipts, traceability: traceability)
        sections.append(("F. Allegato — riepilogo giornaliero", ["Giorno", "Ricezioni", "Tracciati", "Non conformità", "Scaduti"], dailyBreakdown))
        flags.insert(.allegatoPeriodo)

        let dailyRefs = dailyReportReferences(existingDocuments: existingDocuments, restaurantId: restaurant.id, interval: interval)
        sections.append(("G. Riferimenti report giornalieri HACCP combinato", ["Data", "ID documento", "Nome file"], dailyRefs))
        flags.insert(.allegatoPeriodo)

        let suppliers = uniqueSuppliers(receipts: receipts, traceability: traceability, interval: interval)
        sections.append(("H. Fornitori utilizzati nel mese", ["Fornitore"], suppliers.map { [.text($0)] }))
        let importantEvents = importantTraceabilityEvents(logs: logs, traceabilityIds: Set(traceability.map(\.id)), interval: interval, df: df())
        sections.append(("I. Eventi tracciabilità principali", ["Data/ora", "Operatore", "Azione", "Voce"], importantEvents))

        return (sections, flags)
    }

    static func buildAnnualeCombinatoUfficiale(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        interval: DateInterval,
        calendar: Calendar,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        existingDocuments: [DocumentItem]
    ) -> (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags) {
        var flags: OfficialReportSectionFlags = [.intestazione]
        var sections: [(title: String, headers: [String], rows: [[PDFTableCell]])] = []

        sections.append(sectionIntestazioneUfficiale(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt
        ))
        if let logo = sectionLogoIfPresent(logoData: restaurant.logoData) { sections.append(logo) }

        let monthlyAgg = monthlyAggregatesForYear(interval: interval, calendar: calendar, receipts: receipts, traceability: traceability)
        sections.append(("A. Riepilogo per mese", ["Mese", "Ricezioni", "Tracciati", "Non conformità", "Scaduti"], monthlyAgg))
        flags.insert(.allegatoPeriodo)

        let totals = sectionRiepilogo(interval: interval, receipts: receipts, traceability: traceability, links: links)
        sections.append(totals)
        flags.insert(.riepilogo)

        let topSup = topSuppliersAnnual(receipts: receipts, traceability: traceability, interval: interval, limit: 15)
        sections.append(("B. Fornitori principali", ["Fornitore", "Occorrenze"], topSup))

        let catUse = categoryUsageAnnual(receipts: receipts, interval: interval, limit: 12)
        sections.append(("C. Categorie più utilizzate (ricezione)", ["Categoria", "Conteggio"], catUse))

        let ncRows = NonConformityRegister.rows(in: interval, receipts: receipts, traceability: traceability, images: images, df: df())
        sections.append(("D. Non conformità (sintesi annuale)", ["Prodotto", "Stato", "Data", "Origine"], ncRows.map { [.text($0.product), .text($0.stato), .text($0.date), .text($0.source)] }))
        flags.insert(.nonConformita)

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)

        let monthlyIndex = monthlyDocumentIndex(existingDocuments: existingDocuments, restaurantId: restaurant.id, interval: interval)
        sections.append(("E. Indice report mensili HACCP combinato", ["Mese", "ID documento", "Nome file"], monthlyIndex))
        flags.insert(.indiceMensile)

        sections.append(("F. Storico sintetico tracciabilità", ["Indicatore", "Valore"], [
            [.text("Record tracciabilità totali"), .text("\(traceability.filter { interval.contains($0.receivedAt) }.count)")],
            [.text("Ricezioni totali"), .text("\(receipts.filter { interval.contains($0.receivedAt) }.count)")],
            [.text("Collegamenti a produzioni"), .text("\(links.count)")]
        ]))
        flags.insert(.tracciabilita)

        return (sections, flags)
    }

    // MARK: - Moduli singoli (giornaliero)

    static func buildGiornalieroModulo(
        flavor: OfficialReportFlavor,
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog]
    ) -> (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags) {
        var sections: [(title: String, headers: [String], rows: [[PDFTableCell]])] = []
        var flags: OfficialReportSectionFlags = []
        sections.append(sectionIntestazioneUfficiale(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt
        ))
        flags.insert(.intestazione)
        if let logo = sectionLogoIfPresent(logoData: restaurant.logoData) { sections.append(logo) }

        switch flavor {
        case .giornalieroRicezione:
            sections.append(contentsOf: sectionsRicezione(interval: interval, receipts: receipts))
            flags.insert(.ricezioneMerci)
        case .giornalieroTracciabilita:
            sections.append(contentsOf: sectionsTracciabilita(
                interval: interval,
                records: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images
            ))
            flags.insert(.tracciabilita)
        default:
            break
        }

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)
        sections.append(sectionRiepilogo(interval: interval, receipts: receipts, traceability: traceability, links: links))
        flags.insert(.riepilogo)
        return (sections, flags)
    }

    static func buildRegistroNonConformitaMensile(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        logs: [TraceabilityLog]
    ) -> (sections: [(title: String, headers: [String], rows: [[PDFTableCell]])], flags: OfficialReportSectionFlags) {
        var flags: OfficialReportSectionFlags = [.intestazione, .nonConformita]
        var sections: [(title: String, headers: [String], rows: [[PDFTableCell]])] = []
        sections.append(sectionIntestazioneUfficiale(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt
        ))
        sections.append(contentsOf: sectionsNonConformita(interval: interval, receipts: receipts, traceability: traceability, images: images))
        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)
        let rec = receipts.filter { interval.contains($0.receivedAt) }
        let tr = traceability.filter { interval.contains($0.receivedAt) }
        let nc = NonConformityRegister.rows(in: interval, receipts: receipts, traceability: traceability, images: images, df: df()).count
        sections.append(("Riepilogo", ["Indicatore", "Valore"], [
            [.text("Non conformità nel periodo"), .text("\(nc)")],
            [.text("Ricezioni (contesto mese)"), .text("\(rec.count)")],
            [.text("Record tracciabilità (contesto mese)"), .text("\(tr.count)")]
        ]))
        flags.insert(.riepilogo)
        return (sections, flags)
    }

    // MARK: - Helpers

    private static func dailyBreakdownRows(
        interval: DateInterval,
        calendar: Calendar,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord]
    ) -> [[PDFTableCell]] {
        var rows: [[PDFTableCell]] = []
        var day = calendar.startOfDay(for: interval.start)
        let end = interval.end
        let dfDay = dayOnly()
        while day < end {
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
            let di = DateInterval(start: day, end: next)
            let rCount = receipts.filter { di.contains($0.receivedAt) }.count
            let tCount = traceability.filter { di.contains($0.receivedAt) }.count
            let nc = NonConformityRegister.rows(in: di, receipts: receipts, traceability: traceability, images: [], df: df()).count
            let scad = traceability.filter { di.contains($0.receivedAt) && $0.productStatus == .expired }.count
            rows.append([.text(dfDay.string(from: day)), .text("\(rCount)"), .text("\(tCount)"), .text("\(nc)"), .text("\(scad)")])
            day = next
        }
        if rows.isEmpty {
            rows.append([.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—"), .text("—"), .text("—")])
        }
        return rows
    }

    private static func dailyReportReferences(
        existingDocuments: [DocumentItem],
        restaurantId: UUID,
        interval: DateInterval
    ) -> [[PDFTableCell]] {
        let dailies = existingDocuments.filter {
            $0.restaurantId == restaurantId
                && $0.type == .giornaliero
                && $0.module == .haccpCombinato
                && ($0.periodStart.map { interval.contains($0) } ?? false)
        }.sorted { ($0.periodStart ?? .distantPast) < ($1.periodStart ?? .distantPast) }

        let dfDay = dayOnly()
        let rows: [[PDFTableCell]] = dailies.compactMap { doc in
            guard let ps = doc.periodStart else { return nil }
            return [.text(dfDay.string(from: ps)), .text(doc.officialDocumentId.isEmpty ? doc.id.uuidString : doc.officialDocumentId), .text(doc.fileName)]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—")]] : rows
    }

    private static func monthlyDocumentIndex(
        existingDocuments: [DocumentItem],
        restaurantId: UUID,
        interval: DateInterval
    ) -> [[PDFTableCell]] {
        let monthlies = existingDocuments.filter {
            $0.restaurantId == restaurantId
                && $0.type == .mensile
                && $0.module == .haccpCombinato
                && ($0.periodStart.map { interval.contains($0) } ?? false)
        }.sorted { ($0.periodStart ?? .distantPast) < ($1.periodStart ?? .distantPast) }

        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.dateFormat = "MMMM yyyy"
        let rows: [[PDFTableCell]] = monthlies.compactMap { doc in
            guard let ps = doc.periodStart else { return nil }
            return [.text(df.string(from: ps).capitalized), .text(doc.officialDocumentId.isEmpty ? doc.id.uuidString : doc.officialDocumentId), .text(doc.fileName)]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—")]] : rows
    }

    private static func monthlyAggregatesForYear(
        interval: DateInterval,
        calendar: Calendar,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord]
    ) -> [[PDFTableCell]] {
        var rows: [[PDFTableCell]] = []
        var comps = calendar.dateComponents([.year, .month], from: interval.start)
        guard let y0 = comps.year, let m0 = comps.month else { return rows }
        let endComps = calendar.dateComponents([.year, .month], from: interval.end.addingTimeInterval(-1))
        guard let y1 = endComps.year, let m1 = endComps.month else { return rows }
        var y = y0
        var m = m0
        let monthLabelFormatter = DateFormatter()
        monthLabelFormatter.locale = Locale(identifier: "it_IT")
        monthLabelFormatter.dateFormat = "MMMM yyyy"
        while y < y1 || (y == y1 && m <= m1) {
            guard let ms = calendar.date(from: DateComponents(year: y, month: m, day: 1)),
                  let mi = calendar.dateInterval(of: .month, for: ms) else { break }
            let rec = receipts.filter { mi.contains($0.receivedAt) }.count
            let tr = traceability.filter { mi.contains($0.receivedAt) }.count
            let nc = NonConformityRegister.rows(in: mi, receipts: receipts, traceability: traceability, images: [], df: df()).count
            let scad = traceability.filter { mi.contains($0.receivedAt) && $0.productStatus == .expired }.count
            rows.append([.text(monthLabelFormatter.string(from: ms).capitalized), .text("\(rec)"), .text("\(tr)"), .text("\(nc)"), .text("\(scad)")])
            m += 1
            if m > 12 { m = 1; y += 1 }
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—"), .text("—"), .text("—")]] : rows
    }

    private static func uniqueSuppliers(receipts: [GoodsReceipt], traceability: [TraceabilityRecord], interval: DateInterval) -> [String] {
        var s = Set<String>()
        for r in receipts where interval.contains(r.receivedAt) {
            let v = r.supplierNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { s.insert(v) }
        }
        for t in traceability where interval.contains(t.receivedAt) {
            let v = t.supplier.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { s.insert(v) }
        }
        return s.sorted()
    }

    private static func topSuppliersAnnual(
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        interval: DateInterval,
        limit: Int
    ) -> [[PDFTableCell]] {
        var counts: [String: Int] = [:]
        for r in receipts where interval.contains(r.receivedAt) {
            let v = r.supplierNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { continue }
            counts[v, default: 0] += 1
        }
        for t in traceability where interval.contains(t.receivedAt) {
            let v = t.supplier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { continue }
            counts[v, default: 0] += 1
        }
        let sortedPairs = Array(counts.sorted { $0.value > $1.value }.prefix(limit))
        let rows: [[PDFTableCell]] = sortedPairs.map { pair in
            [.text(pair.key), .text("\(pair.value)")]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—")]] : rows
    }

    private static func categoryUsageAnnual(receipts: [GoodsReceipt], interval: DateInterval, limit: Int) -> [[PDFTableCell]] {
        var counts: [String: Int] = [:]
        for r in receipts where interval.contains(r.receivedAt) {
            counts[r.category.rawValue, default: 0] += 1
        }
        let sortedPairs = Array(counts.sorted { $0.value > $1.value }.prefix(limit))
        let rows: [[PDFTableCell]] = sortedPairs.map { pair in
            [.text(pair.key), .text("\(pair.value)")]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—")]] : rows
    }

    private static func importantTraceabilityEvents(
        logs: [TraceabilityLog],
        traceabilityIds: Set<UUID>,
        interval: DateInterval,
        df: DateFormatter
    ) -> [[PDFTableCell]] {
        let filtered = logs.filter { traceabilityIds.contains($0.receivedItemId) && interval.contains($0.timestamp) }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(200)
        let rows: [[PDFTableCell]] = filtered.map { log in
            let action: String = switch log.actionType {
            case .created: "Creazione"
            case .linkedToProduction: "Collegamento produzione"
            case .expired: "Scadenza"
            case .rejected: "Respinto"
            case .nonCompliance: "Non conformità"
            }
            return [.text(df.string(from: log.timestamp)), .text(log.operatorName), .text(action), .text(String(log.receivedItemId.uuidString.prefix(8)).uppercased())]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—"), .text("—")]] : rows
    }
}
