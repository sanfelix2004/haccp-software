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

    // MARK: - Apertura e chiusura documento

    private static func documentKindLabel(type: DocumentType, module: DocumentModule) -> String {
        let moduleLabel = DocumentArchiveLayout.moduleFolderTitle(module)
        switch type {
        case .giornaliero: return "Registro giornaliero — \(moduleLabel)"
        case .settimanale: return "Registro settimanale — \(moduleLabel)"
        case .mensile: return "Registro mensile — \(moduleLabel)"
        case .annuale: return "Registro annuale — \(moduleLabel)"
        case .nonConformita: return "Registro non conformità"
        default: return "Documento HACCP — \(moduleLabel)"
        }
    }

    private static func openingSections(
        restaurant: Restaurant,
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        documentKind: String
    ) -> [HACCPPDFSection] {
        var sections: [HACCPPDFSection] = [
            .prose(title: "Premessa", paragraphs: HACCPPDFLegalBlocks.preambleParagraphs()),
            sectionIdentificativoDocumento(
                reportTitle: reportTitle,
                reportDateLine: reportDateLine,
                periodLine: periodLine,
                officialDocumentId: officialDocumentId,
                generatedAt: generatedAt,
                documentKind: documentKind
            )
        ]
        if let logo = sectionLogoIfPresent(logoData: restaurant.logoData) {
            sections.append(logo)
        }
        return sections
    }

    private static func finalizeDocument(_ sections: inout [HACCPPDFSection], restaurant: Restaurant) {
        HACCPPDFLegalBlocks.appendClosingSections(to: &sections, restaurant: restaurant)
    }

    static func sectionIdentificativoDocumento(
        reportTitle: String,
        reportDateLine: String,
        periodLine: String,
        officialDocumentId: String,
        generatedAt: Date,
        documentKind: String
    ) -> HACCPPDFSection {
        let formatter = df()
        let rows: [[PDFTableCell]] = [
            [.text("Tipologia documento"), .text(documentKind)],
            [.text("Titolo registro"), .text(reportTitle)],
            [.text("Data di redazione"), .text(reportDateLine)],
            [.text("Ambito temporale"), .text(periodLine)],
            [.text("Data e ora generazione"), .text(formatter.string(from: generatedAt))],
            [.text("Versione software"), .text(HACCPAppBuildVersion.marketingAndBuild)],
            [.text("Identificativo univoco"), .text(officialDocumentId)],
            [.text("Fonte dati"), .text(HACCPRegisterCopy.dataSourceNote)],
            [.text("Riferimento normativo"), .text(HACCPPDFLegalBlocks.normativeReference)]
        ]
        return .keyValueTable(
            title: "Scheda identificativa",
            subtitle: "Elementi obbligatori per l'archiviazione del registro",
            rows: rows
        )
    }

    static func sectionLogoIfPresent(logoData: Data?) -> HACCPPDFSection? {
        guard let logoData, !logoData.isEmpty else { return nil }
        return .dataTable(title: "Logo esercizio", headers: ["Marchio / logo"], rows: [[img(logoData)]])
    }

    // MARK: - Ricezione / Tracciabilità / NC

    static func sectionsRicezione(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        images: [ProductImage] = []
    ) -> [HACCPPDFSection] {
        let formatter = df()
        let rows = GoodsReceiptRegister.rows(in: interval, receipts: receipts, images: images, df: formatter)
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
                .image(r.photoData.flatMap { HACCPPDFImageCompression.compressedJPEGData(from: $0) }),
                .text(r.photoCount > 1 ? "\(r.photoCount) foto" : (r.photoData == nil ? "—" : "1 foto"))
            ]
        }
        let body = table.isEmpty ? [emptyOperationalRow(columns: 15)] : table
        let headers = [
            "Denominazione prodotto", "Categoria", "Fornitore", "N. lotto", "Data scadenza", "Data e ora ricezione",
            "Temperatura rilevata", "Range ammesso", "Esito temperatura", "Esito checklist", "Esito complessivo",
            "Annotazioni", "Operatore addetto", "Foto", "N. foto"
        ]
        return [
            .dataTable(
                title: "Registro ricezione merci e materie prime",
                subtitle: "Controllo in ingresso — temperatura, checklist, conformità e documentazione fotografica",
                headers: headers,
                rows: body
            )
        ]
    }

    static func sectionsTracciabilita(
        interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        lottoFotos: [LottoFoto] = []
    ) -> [HACCPPDFSection] {
        let formatter = df()
        let rows = TraceabilityRegister.rows(
            in: interval,
            records: records,
            productions: productions,
            links: links,
            logs: logs,
            images: images,
            lottoFotos: lottoFotos,
            df: formatter
        )
        let table: [[PDFTableCell]] = rows.map { r in
            [
                .text(r.product),
                .text(r.lot),
                .text(r.supplier),
                .text(r.createdAt),
                .text(r.createdBy),
                .text(r.associations),
                .text(r.closure),
                .text(r.status),
                .text(r.nonCompliance),
                .image(r.photoData.flatMap { HACCPPDFImageCompression.compressedJPEGData(from: $0) })
            ]
        }
        let body = table.isEmpty ? [emptyOperationalRow(columns: 10)] : table
        let headers = [
            "Prodotto",
            "Lotto",
            "Fornitore / origine",
            "Creato il",
            "Registrato da",
            "Associato a (quando / da chi)",
            "Chiusura (esito · quando · chi)",
            "Stato",
            "Non conformità",
            "Foto"
        ]
        return [
            .dataTable(
                title: "Registro tracciabilità",
                subtitle: "Ciclo completo: creazione → associazioni → foto/lotti → chiusura (con motivo)",
                headers: headers,
                rows: body
            )
        ]
    }

    static func sectionsRegistroProduzioniTracciabilita(
        interval: DateInterval,
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog] = [],
        operational: HACCPOperationalSourceData,
        df: DateFormatter
    ) -> [HACCPPDFSection] {
        let blocks = ProductionTraceabilityRegister.masterBlocks(
            in: interval,
            traceability: traceability,
            productions: productions,
            links: links,
            labels: operational.productionLabels,
            batches: operational.produzioneBatches,
            ingredientiTracciati: operational.ingredientiTracciati,
            lottoLinks: operational.lottoProductionLinks,
            lottoFotos: operational.lottoFotos,
            productImages: operational.productImages,
            logs: logs,
            df: df
        )

        var tableRows: [[PDFTableCell]] = []
        let headers = [
            "Data / Operatore",
            "Produzione / Alimento",
            "Lotto",
            "Scadenze",
            "Foto"
        ]

        if blocks.isEmpty {
            tableRows.append(emptyOperationalRow(columns: headers.count))
        } else {
            for block in blocks {
                let batchPhoto = block.dishPhotoData
                    ?? block.batchId.flatMap { batchId in
                        ProductImageBytesResolver.productionDishPhoto(
                            batchId: batchId,
                            images: operational.productImages,
                            records: traceability
                        )
                    }
                tableRows.append([
                    .text(block.dateOperator),
                    .text(block.productionDetail),
                    .text(block.lotDetail),
                    .text(block.expiryDetail),
                    .image(batchPhoto.flatMap { HACCPPDFImageCompression.compressedJPEGData(from: $0) })
                ])
                if block.ingredients.isEmpty {
                    tableRows.append([
                        .text("↳ Ingredienti"),
                        .text(HACCPRegisterCopy.notAvailable),
                        .text("—"),
                        .text("—"),
                        .text("—")
                    ])
                } else {
                    for line in block.ingredients {
                        let photo = line.photoData
                            ?? line.recordId.flatMap { id in
                                traceability.first(where: { $0.id == id }).flatMap { record in
                                    ProductImageBytesResolver.resolve(
                                        record: record,
                                        images: operational.productImages,
                                        lottoFotos: operational.lottoFotos
                                    )
                                }
                            }
                        tableRows.append([
                            .text(line.dateOperator),
                            .text(line.foodDetail),
                            .text(line.lot),
                            .text(line.expiryDetail),
                            .image(photo.flatMap { HACCPPDFImageCompression.compressedJPEGData(from: $0) })
                        ])
                    }
                }
                tableRows.append([
                    .text(" "),
                    .text(" "),
                    .text(" "),
                    .text(" "),
                    .text(" ")
                ])
            }
        }

        var sections: [HACCPPDFSection] = [
            .dataTable(
                title: "Registro produzioni e tracciabilità",
                subtitle: "Piatto finito con lotto, foto, ingredienti, scadenze e operatori — ciclo leggibile per ASL",
                headers: headers,
                rows: tableRows
            )
        ]

        let movements = operational.documentMovements
            .filter { interval.contains($0.occurredAt) }
            // Solo eventi operativi da conservare: completamenti e chiusure scadenze.
            // Niente soft-hide / errori di inserimento (quelli non devono restare nei documenti).
            .filter {
                $0.kind == .productionCompleted || $0.kind == .lotClosedFromExpiryControl
            }
            .sorted { $0.occurredAt > $1.occurredAt }
        let movementHeaders = ["Data / Operatore", "Evento", "Produzione / Lotto", "Dettaglio"]
        let movementRows: [[PDFTableCell]] = {
            if movements.isEmpty {
                return [emptyOperationalRow(columns: movementHeaders.count)]
            }
            return movements.map { m in
                let title = [m.productionName, m.lotCode.map { "Lotto \($0)" }]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                return [
                    .text("\(df.string(from: m.occurredAt)) · \(m.operatorName)"),
                    .text(m.kindLabel),
                    .text(title.isEmpty ? "—" : title),
                    .text(m.summary)
                ]
            }
        }()
        sections.append(
            .dataTable(
                title: "Registro movimenti",
                subtitle: "Produzioni completate e chiusure da Controllo scadenze (terminato / scaduto / scartato / usato)",
                headers: movementHeaders,
                rows: movementRows
            )
        )
        return sections
    }

    static func sectionsProduzioniConIngredienti(
        interval: DateInterval,
        productions: [Production],
        incomingIngredients: [ProductionIncomingIngredient],
        links: [TraceabilityLink],
        traceability: [TraceabilityRecord]
    ) -> [HACCPPDFSection] {
        let formatter = df()
        let rows = ProductionIngredientRegister.rows(
            in: interval,
            productions: productions,
            incomingIngredients: incomingIngredients,
            links: links,
            traceability: traceability,
            df: formatter
        )
        let table: [[PDFTableCell]] = rows.map {
            [
                .text($0.production),
                .text($0.category),
                .text($0.ingredientsConfigured),
                .text($0.lotsUsedInPeriod),
                .text($0.lastLinkedAt)
            ]
        }
        let body = table.isEmpty ? [emptyOperationalRow(columns: 5)] : table
        return [
            .dataTable(
                title: "Produzioni e ingredienti associati",
                subtitle: "Catalogo piatti, ricetta configurata e lotti collegati nel periodo",
                headers: ["Produzione", "Categoria", "Ingredienti in ricetta", "Lotti usati nel periodo", "Ultimo collegamento"],
                rows: body
            )
        ]
    }

    static func sectionsNonConformita(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage]
    ) -> [HACCPPDFSection] {
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
                .image(r.photoData.flatMap { HACCPPDFImageCompression.compressedJPEGData(from: $0) }),
                .text(r.stato),
                .text(r.risoltaDa),
                .text(r.risoltaIl),
                .text(r.date),
                .text(r.operatorName),
                .text(r.source)
            ]
        }
        let headers = [
            "Prodotto", "Lotto", "Descrizione NC", "Azione correttiva", "Foto",
            "Stato pratica", "Chiusa da", "Data chiusura", "Data rilevazione", "Operatore", "Modulo origine"
        ]
        return [
            .dataTable(
                title: "Registro non conformità e azioni correttive",
                subtitle: "Anomalie rilevate, trattamento e stato di risoluzione",
                headers: headers,
                rows: table
            )
        ]
    }

    // MARK: - Criticità

    static func sectionEventiImportanti(
        restaurantId: UUID,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        traceabilityRecordIds: Set<UUID>
    ) -> HACCPPDFSection {
        let formatter = df()
        let events = HACCPDocumentAuditLogBuilder.importantRows(
            restaurantId: restaurantId,
            interval: interval,
            receipts: receipts,
            traceabilityRecords: traceability,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: traceabilityLogs,
            traceabilityRecordIds: traceabilityRecordIds,
            df: formatter
        )
        let rows: [[PDFTableCell]] = events.map { r in
            [.text(r.timestamp), .text(r.module), .text(r.action), .text(r.detail), .text(r.operatorName)]
        }
        let table = rows.isEmpty
            ? [[.text(HACCPRegisterCopy.noCriticalEvents), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable)]]
            : rows
        return .dataTable(
            title: "Sintesi criticità e eventi rilevanti",
            subtitle: "Solo anomalie, NC e controlli non conformi (max. 60 eventi)",
            headers: ["Data e ora", "Modulo", "Tipo evento", "Descrizione sintetica", "Operatore"],
            rows: table
        )
    }

    /// Compatibilità interna con chiamate esistenti.
    static func sectionAudit(
        restaurantId: UUID,
        interval: DateInterval,
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        traceabilityLogs: [TraceabilityLog],
        traceabilityRecordIds: Set<UUID>,
        receipts: [GoodsReceipt] = [],
        traceability: [TraceabilityRecord] = []
    ) -> HACCPPDFSection {
        sectionEventiImportanti(
            restaurantId: restaurantId,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: traceabilityLogs,
            traceabilityRecordIds: traceabilityRecordIds
        )
    }

    // MARK: - Riepilogo

    static func sectionRiepilogo(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        links: [TraceabilityLink],
        operational: HACCPOperationalSourceData = HACCPOperationalSourceData()
    ) -> HACCPPDFSection {
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
        let rejected = tr.filter { $0.productStatus == .rejected }.count
        let linkedIds = Set(links.map(\.receivedItemId))
        let withProd = tr.filter { linkedIds.contains($0.id) }.count
        let recIssues = rec.filter { $0.status != .conforme || $0.temperatureStatus == .nonConforme }.count
        let checklistFails = rec.filter { $0.checklistResults.contains(where: { $0.value == .notOk }) }.count
        let tempReadings = operational.temperatureRecords.filter { interval.contains($0.measuredAt) }.count
        let tempIssues = operational.temperatureRecords.filter { interval.contains($0.measuredAt) && $0.status != .ok }.count
        let cleaningDone = CleaningRegister.unifiedRows(
            in: interval,
            records: operational.cleaningRecords,
            runs: operational.checklistRuns,
            itemResults: operational.checklistItemResults,
            templates: operational.checklistTemplates,
            df: df()
        ).count
        let defrostCount = operational.defrostRecords.filter { interval.contains($0.startAt) }.count
        let blastCount = operational.blastChillingRecords.filter { interval.contains($0.startedAt) }.count
        let oilChecks = operational.oilControlRecords.filter { interval.contains($0.checkedAt) }.count
        let checklistRuns = operational.checklistRuns.filter { interval.contains($0.startedAt) }.count
        let labelsCount = operational.productionLabels.filter { interval.contains($0.createdAt) }.count

        let rows: [[PDFTableCell]] = [
            [.text("Ricezioni registrate"), .text("\(rec.count)")],
            [.text("Prodotti tracciati"), .text("\(tr.count)")],
            [.text("Non conformità totali"), .text("\(ncCount)")],
            [.text("Ricezioni con anomalie"), .text("\(recIssues)")],
            [.text("Temperature fuori range (ricezione)"), .text("\(rec.filter { $0.temperatureStatus == .nonConforme }.count)")],
            [.text("Checklist con voci NON OK (ricezione)"), .text("\(checklistFails)")],
            [.text("Rilevazioni temperatura frigoriferi"), .text("\(tempReadings)")],
            [.text("Rilevazioni temperatura non conformi"), .text("\(tempIssues)")],
            [.text("Controlli pulizia registrati"), .text("\(cleaningDone)")],
            [.text("Processi decongelamento"), .text("\(defrostCount)")],
            [.text("Processi abbattimento"), .text("\(blastCount)")],
            [.text("Controlli olio"), .text("\(oilChecks)")],
            [.text("Checklist completate"), .text("\(checklistRuns)")],
            [.text("Etichette di produzione emesse"), .text("\(labelsCount)")],
            [.text("Prodotti scaduti"), .text("\(expired)")],
            [.text("Prodotti respinti"), .text("\(rejected)")],
            [.text("Collegamenti a produzioni"), .text("\(withProd)")],
            [.text("Nota"), .text("Sintesi automatica calcolata sui dati registrati in applicazione nel periodo indicato.")]
        ]
        return .keyValueTable(
            title: "Quadro riepilogativo del periodo",
            subtitle: "Indicatori quantitativi per verifica rapida dello stato HACCP",
            rows: rows
        )
    }

    /// Quadro riepilogativo ristretto al registro «Tracciabilità e produzioni» (senza metriche di altri moduli).
    static func sectionRiepilogoTracciabilitaProduzioni(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        links: [TraceabilityLink]
    ) -> HACCPPDFSection {
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
        let rejected = tr.filter { $0.productStatus == .rejected }.count
        let linkedIds = Set(links.map(\.receivedItemId))
        let withProd = tr.filter { linkedIds.contains($0.id) }.count
        let recIssues = rec.filter { $0.status != .conforme || $0.temperatureStatus == .nonConforme }.count

        let rows: [[PDFTableCell]] = [
            [.text("Ricezioni registrate"), .text("\(rec.count)")],
            [.text("Prodotti tracciati"), .text("\(tr.count)")],
            [.text("Non conformità totali"), .text("\(ncCount)")],
            [.text("Ricezioni con anomalie"), .text("\(recIssues)")],
            [.text("Prodotti scaduti"), .text("\(expired)")],
            [.text("Prodotti respinti"), .text("\(rejected)")],
            [.text("Collegamenti a produzioni"), .text("\(withProd)")],
            [.text("Nota"), .text("Sintesi tracciabilità e produzioni calcolata sui dati registrati nel periodo indicato.")]
        ]
        return .keyValueTable(
            title: "Quadro riepilogativo del periodo",
            subtitle: "Indicatori quantitativi pertinenti al registro tracciabilità e produzioni",
            rows: rows
        )
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
        temperatureLogs: [TemperatureAuditLog],
        existingDocuments: [DocumentItem],
        operational: HACCPOperationalSourceData
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = []
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Report HACCP combinato giornaliero"
        )
        flags.insert(.intestazione)

        let body = combinatoStandardBody(
            restaurant: restaurant,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            links: links,
            logs: logs,
            images: images,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            existingDocuments: existingDocuments,
            operational: operational,
            documentType: .giornaliero
        )
        sections.append(contentsOf: body.sections)
        flags.formUnion(body.flags)

        finalizeDocument(&sections, restaurant: restaurant)
        return (sections, flags)
    }

    private static func combinatoStandardBody(
        restaurant: Restaurant,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        checklistLogs: [ChecklistAuditLog],
        temperatureLogs: [TemperatureAuditLog],
        existingDocuments: [DocumentItem],
        operational: HACCPOperationalSourceData,
        documentType: DocumentType
    ) -> (sections: [HACCPPDFSection], flags: OfficialReportSectionFlags) {
        var flags: OfficialReportSectionFlags = []
        var sections: [HACCPPDFSection] = []

        sections.append(sectionRiepilogo(
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            links: links,
            operational: operational
        ))
        flags.insert(.riepilogo)

        sections.append(.dataTable(
            title: "Indice report mensili per modulo",
            subtitle: "Collegamenti ai singoli registri del mese",
            headers: ["Modulo", "Identificativo documento", "Nome file archiviato"],
            rows: singoliDocumentIndex(
                existingDocuments: existingDocuments,
                restaurantId: restaurant.id,
                interval: interval,
                documentType: documentType
            )
        ))
        flags.insert(.allegatoPeriodo)

        sections.append(sectionSintesiNonConformita(
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            images: images
        ))
        flags.insert(.nonConformita)

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionEventiImportanti(
            restaurantId: restaurant.id,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)

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
        existingDocuments: [DocumentItem],
        operational: HACCPOperationalSourceData
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = []
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Report HACCP combinato mensile"
        )
        flags.insert(.intestazione)

        let body = combinatoStandardBody(
            restaurant: restaurant,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            links: links,
            logs: logs,
            images: images,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            existingDocuments: existingDocuments,
            operational: operational,
            documentType: .mensile
        )
        sections.append(contentsOf: body.sections)
        flags.formUnion(body.flags)

        let suppliers = uniqueSuppliers(receipts: receipts, traceability: traceability, interval: interval)
        sections.append(.dataTable(
            title: "Elenco fornitori del mese",
            subtitle: "Fornitori presenti in ricezione e tracciabilità",
            headers: ["Ragione sociale / fornitore"],
            rows: suppliers.map { [.text($0)] }
        ))
        flags.insert(.allegatoPeriodo)

        finalizeDocument(&sections, restaurant: restaurant)
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
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = [.intestazione]
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Report HACCP combinato annuale"
        )

        let monthlyAgg = monthlyAggregatesForYear(interval: interval, calendar: calendar, receipts: receipts, traceability: traceability)
        sections.append(.dataTable(
            title: "Riepilogo mensile dell'anno",
            headers: ["Mese", "Ricezioni", "Tracciati", "Non conformità", "Prodotti scaduti"],
            rows: monthlyAgg
        ))
        flags.insert(.allegatoPeriodo)

        sections.append(sectionRiepilogo(interval: interval, receipts: receipts, traceability: traceability, links: links))
        flags.insert(.riepilogo)

        let topSup = topSuppliersAnnual(receipts: receipts, traceability: traceability, interval: interval, limit: 15)
        sections.append(.dataTable(
            title: "Fornitori principali dell'anno",
            headers: ["Fornitore", "N. occorrenze"],
            rows: topSup
        ))

        let catUse = categoryUsageAnnual(receipts: receipts, interval: interval, limit: 12)
        sections.append(.dataTable(
            title: "Categorie merceologiche più utilizzate",
            headers: ["Categoria", "Conteggio ricezioni"],
            rows: catUse
        ))

        let ncRows = NonConformityRegister.rows(in: interval, receipts: receipts, traceability: traceability, images: images, df: df())
        sections.append(.dataTable(
            title: "Sintesi annuale non conformità",
            headers: ["Prodotto", "Stato pratica", "Data", "Modulo origine"],
            rows: ncRows.map { [.text($0.product), .text($0.stato), .text($0.date), .text($0.source)] }
        ))
        flags.insert(.nonConformita)

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds,
            receipts: receipts,
            traceability: traceability
        ))
        flags.insert(.auditLog)

        let monthlyIndex = monthlyDocumentIndex(existingDocuments: existingDocuments, restaurantId: restaurant.id, interval: interval)
        sections.append(.dataTable(
            title: "Indice report mensili archivio",
            headers: ["Modulo", "Identificativo documento", "Nome file"],
            rows: monthlyIndex
        ))
        flags.insert(.indiceMensile)

        sections.append(.keyValueTable(
            title: "Storico sintetico tracciabilità",
            rows: [
                [.text("Record tracciabilità totali"), .text("\(traceability.filter { interval.contains($0.receivedAt) }.count)")],
                [.text("Ricezioni totali"), .text("\(receipts.filter { interval.contains($0.receivedAt) }.count)")],
                [.text("Collegamenti a produzioni"), .text("\(links.count)")]
            ]
        ))
        flags.insert(.tracciabilita)

        finalizeDocument(&sections, restaurant: restaurant)
        return (sections, flags)
    }

    static func buildMensileAffinityCombined(
        combinedModule: DocumentModule,
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
        temperatureLogs: [TemperatureAuditLog],
        operational: HACCPOperationalSourceData
    ) -> HACCPPDFSectionBundle {
        let title = DocumentArchiveLayout.moduleFolderTitle(combinedModule)
        var flags: OfficialReportSectionFlags = [.intestazione]
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Report combinato mensile — \(title)"
        )

        if combinedModule == .combinatoTracciabilitaProduzione {
            sections.append(contentsOf: sectionsRegistroProduzioniTracciabilita(
                interval: interval,
                traceability: traceability,
                productions: productions,
                links: links,
                logs: logs,
                operational: operational,
                df: df()
            ))
            flags.insert(.tracciabilita)
        } else {
            for source in DocumentArchiveLayout.sourceModules(for: combinedModule) {
                let partial = buildSingoloModulo(
                    documentType: .mensile,
                    module: source,
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
                    temperatureLogs: temperatureLogs,
                    operational: operational,
                    contentOnly: true
                )
                sections.append(contentsOf: partial.sections)
                flags.formUnion(partial.flags)
            }
        }

        if combinedModule == .combinatoTracciabilitaProduzione {
            sections.append(sectionRiepilogoTracciabilitaProduzioni(
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                links: links
            ))
        } else {
            sections.append(sectionRiepilogo(
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                links: links,
                operational: operational
            ))
        }
        flags.insert(.riepilogo)

        finalizeDocument(&sections, restaurant: restaurant)
        return (sections, flags)
    }

    // MARK: - Documenti singoli per modulo

    static func buildSingoloModulo(
        documentType: DocumentType,
        module: DocumentModule,
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
        temperatureLogs: [TemperatureAuditLog],
        operational: HACCPOperationalSourceData,
        contentOnly: Bool = false
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = contentOnly ? [] : [.intestazione]
        var sections: [HACCPPDFSection] = []
        if !contentOnly {
            sections = openingSections(
                restaurant: restaurant,
                reportTitle: reportTitle,
                reportDateLine: reportDateLine,
                periodLine: periodLine,
                officialDocumentId: officialDocumentId,
                generatedAt: generatedAt,
                documentKind: documentKindLabel(type: documentType, module: module)
            )
        }
        let formatter = df()

        appendModuleRegisterContent(
            to: &sections,
            flags: &flags,
            module: module,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            productions: productions,
            links: links,
            logs: logs,
            images: images,
            operational: operational,
            formatter: formatter
        )

        if contentOnly {
            return (sections, flags)
        }

        sections.append(sectionRiepilogo(
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            links: links,
            operational: operational
        ))
        flags.insert(.riepilogo)

        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionEventiImportanti(
            restaurantId: restaurant.id,
            interval: interval,
            receipts: receipts,
            traceability: traceability,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds
        ))
        flags.insert(.auditLog)

        finalizeDocument(&sections, restaurant: restaurant)
        return (sections, flags)
    }

    private static func appendModuleRegisterContent(
        to sections: inout [HACCPPDFSection],
        flags: inout OfficialReportSectionFlags,
        module: DocumentModule,
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        operational: HACCPOperationalSourceData,
        formatter: DateFormatter
    ) {
        switch module {
        case .ricezioneMerci:
            sections.append(contentsOf: sectionsRicezione(interval: interval, receipts: receipts, images: images))
            flags.insert(.ricezioneMerci)
        case .tracciabilita:
            // Documento principale: produzioni + ingredienti + movimenti.
            sections.append(contentsOf: sectionsRegistroProduzioniTracciabilita(
                interval: interval,
                traceability: traceability,
                productions: productions,
                links: links,
                logs: logs,
                operational: operational,
                df: formatter
            ))
            sections.append(contentsOf: sectionsTracciabilita(
                interval: interval,
                records: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                lottoFotos: operational.lottoFotos
            ))
            flags.insert(.tracciabilita)
        case .frigoriferi:
            let rows = TemperatureRegister.rows(in: interval, records: operational.temperatureRecords, df: formatter)
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.device), .text($0.measuredAt), .text($0.value), .text($0.range), .text($0.status), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 7)] : table
            sections.append(.dataTable(
                title: "Registro temperature apparecchi frigoriferi",
                subtitle: "Monitoraggio temperature di conservazione",
                headers: ["Apparecchio / cella", "Data e ora rilevazione", "Temperatura", "Range ammesso", "Esito controllo", "Operatore addetto", "Annotazioni"],
                rows: body
            ))
        case .controlloPulizia:
            let rows = CleaningRegister.unifiedRows(
                in: interval,
                records: operational.cleaningRecords,
                runs: operational.checklistRuns,
                itemResults: operational.checklistItemResults,
                templates: operational.checklistTemplates,
                df: formatter
            )
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.area), .text($0.task), .text($0.frequency), .text($0.period), .text($0.outcome), .text($0.operatorName), .text($0.notes), .text($0.source)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 8)] : table
            sections.append(.dataTable(
                title: "Registro sanificazione e pulizia",
                subtitle: "Piano sanificazione e checklist igieniche unificate (senza duplicati bridge)",
                headers: ["Area / zona", "Attività", "Frequenza prevista", "Periodo di riferimento", "Esito", "Operatore addetto", "Annotazioni", "Fonte"],
                rows: body
            ))
        case .abbattimento:
            let rows = BlastChillingRegister.rows(in: interval, records: operational.blastChillingRecords, df: formatter)
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.production), .text($0.category), .text($0.lot), .text($0.startedAt), .text($0.endedAt), .text($0.duration), .text($0.initialTemp), .text($0.finalTemp), .text($0.targetTemp), .text($0.status), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 12)] : table
            sections.append(.dataTable(
                title: "Registro abbattimento rapido",
                subtitle: "Processi di abbattimento termico completi di temperature e lotti",
                headers: ["Produzione", "Categoria", "Lotto", "Inizio", "Fine", "Durata", "T° iniz.", "T° fin.", "T° target", "Esito", "Operatore", "Note / azioni"],
                rows: body
            ))
        case .decongelamento:
            let rows = DefrostRegister.rows(in: interval, records: operational.defrostRecords, df: formatter)
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.product), .text($0.method), .text($0.lot), .text($0.startedAt), .text($0.expectedEndAt), .text($0.endedAt), .text($0.duration), .text($0.initialTemp), .text($0.finalTemp), .text($0.status), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 12)] : table
            sections.append(.dataTable(
                title: "Registro decongelamento",
                subtitle: "Gestione sicura del decongelamento prodotti con temperature e tempistiche",
                headers: ["Prodotto", "Metodo", "Lotto", "Inizio", "Prev. fine", "Fine", "Durata", "T° iniz.", "T° fin.", "Stato", "Operatore", "Note / azioni"],
                rows: body
            ))
        case .controlloOlio:
            let rows = OilControlRegister.rows(in: interval, records: operational.oilControlRecords, df: formatter)
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.point), .text($0.checkedAt), .text($0.status), .text($0.polarCompounds), .text($0.temperature), .text($0.action), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 8)] : table
            sections.append(.dataTable(
                title: "Registro controllo olio da frittura",
                subtitle: "Composti polari, temperatura e sostituzione olio",
                headers: ["Punto di frittura", "Data e ora controllo", "Stato olio", "Composti polari (%)", "Temperatura", "Azione intrapresa", "Operatore", "Annotazioni"],
                rows: body
            ))
        case .checklist:
            let rows = ChecklistRegister.rows(
                in: interval,
                runs: operational.checklistRuns,
                itemResults: operational.checklistItemResults,
                df: formatter
            )
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.checklist), .text($0.status), .text($0.startedAt), .text($0.completedAt), .text($0.progress), .text($0.failedItems), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 8)] : table
            sections.append(.dataTable(
                title: "Registro checklist operative",
                subtitle: "Verifiche periodiche e controlli strutturati",
                headers: ["Checklist", "Stato esecuzione", "Inizio", "Fine", "Completamento", "Voci non conformi", "Operatore", "Annotazioni"],
                rows: body
            ))
        case .etichetteProduzione:
            let rows = ProductionLabelsRegister.rows(in: interval, labels: operational.productionLabels, df: formatter)
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.product), .text($0.lot), .text($0.category), .text($0.supplier),
                 .text($0.producedAt), .text($0.expiresAt), .text($0.status), .text($0.source),
                 .text($0.reprints), .text($0.operatorName), .text($0.notes)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 11)] : table
            sections.append(.dataTable(
                title: "Registro etichette di produzione",
                subtitle: "Etichette HACCP emesse nel periodo (tracciabilità interna)",
                headers: ["Prodotto", "Lotto", "Categoria", "Fornitore", "Data produzione", "Scadenza",
                          "Stato prodotto", "Modulo origine", "Ristampe", "Operatore", "Annotazioni"],
                rows: body
            ))
        case .controlloScadenze:
            let rows = ExpiryControlRegister.productionRows(
                in: interval,
                records: traceability,
                logs: logs,
                df: formatter
            )
            let table: [[PDFTableCell]] = rows.map {
                [.text($0.product), .text($0.lot), .text($0.expiry), .text($0.status),
                 .text($0.source), .text($0.registeredAt), .text($0.operatorName)]
            }
            let body = table.isEmpty ? [emptyOperationalRow(columns: 7)] : table
            sections.append(.dataTable(
                title: "Registro controllo scadenze",
                subtitle: "Stato operativo: disponibile, terminato, usato, scaduto, scartato",
                headers: ["Prodotto", "Lotto", "Scadenza", "Stato", "Tipo", "Registrato il", "Operatore"],
                rows: body
            ))
            flags.insert(.tracciabilita)
        default:
            break
        }
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
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = []
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Registro giornaliero modulo singolo"
        )
        flags.insert(.intestazione)

        sections.append(sectionRiepilogo(interval: interval, receipts: receipts, traceability: traceability, links: links))
        flags.insert(.riepilogo)

        switch flavor {
        case .giornalieroRicezione:
            sections.append(contentsOf: sectionsRicezione(interval: interval, receipts: receipts, images: images))
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
            traceabilityRecordIds: traceIds,
            receipts: receipts,
            traceability: traceability
        ))
        flags.insert(.auditLog)

        finalizeDocument(&sections, restaurant: restaurant)
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
    ) -> HACCPPDFSectionBundle {
        var flags: OfficialReportSectionFlags = [.intestazione, .nonConformita]
        var sections = openingSections(
            restaurant: restaurant,
            reportTitle: reportTitle,
            reportDateLine: reportDateLine,
            periodLine: periodLine,
            officialDocumentId: officialDocumentId,
            generatedAt: generatedAt,
            documentKind: "Registro non conformità mensile"
        )

        let rec = receipts.filter { interval.contains($0.receivedAt) }
        let tr = traceability.filter { interval.contains($0.receivedAt) }
        let nc = NonConformityRegister.rows(in: interval, receipts: receipts, traceability: traceability, images: images, df: df()).count
        sections.append(.keyValueTable(
            title: "Sintesi del periodo",
            rows: [
                [.text("Non conformità nel periodo"), .text("\(nc)")],
                [.text("Ricezioni registrate"), .text("\(rec.count)")],
                [.text("Prodotti tracciati"), .text("\(tr.count)")]
            ]
        ))
        flags.insert(.riepilogo)

        sections.append(contentsOf: sectionsNonConformita(interval: interval, receipts: receipts, traceability: traceability, images: images))
        let traceIds = Set(traceability.map(\.id))
        sections.append(sectionAudit(
            restaurantId: restaurant.id,
            interval: interval,
            checklistLogs: checklistLogs,
            temperatureLogs: temperatureLogs,
            traceabilityLogs: logs,
            traceabilityRecordIds: traceIds,
            receipts: receipts,
            traceability: traceability
        ))
        flags.insert(.auditLog)

        finalizeDocument(&sections, restaurant: restaurant)
        return (sections, flags)
    }

    // MARK: - Helpers

    private static func emptyOperationalRow(columns: Int) -> [PDFTableCell] {
        var cells: [PDFTableCell] = [.text(HACCPRegisterCopy.noActivityInPeriod)]
        if columns > 1 {
            for _ in 1..<columns {
                cells.append(.text(HACCPRegisterCopy.notAvailable))
            }
        }
        return cells
    }

    private static func sectionSintesiNonConformita(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage]
    ) -> HACCPPDFSection {
        let formatter = df()
        let all = NonConformityRegister.rows(
            in: interval,
            receipts: receipts,
            traceability: traceability,
            images: images,
            df: formatter
        )
        let rows: [[PDFTableCell]] = all.prefix(25).map { r in
            [.text(r.product), .text(r.lot), .text(r.reason), .text(r.stato), .text(r.date), .text(r.source)]
        }
        let table = rows.isEmpty
            ? [[.text(HACCPRegisterCopy.noNonConformities), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable), .text(HACCPRegisterCopy.notAvailable)]]
            : rows
        return .dataTable(
            title: "Sintesi non conformità del periodo",
            subtitle: "Elenco delle principali anomalie (max. 25 voci)",
            headers: ["Prodotto", "Lotto", "Descrizione", "Stato", "Data", "Origine"],
            rows: table
        )
    }

    private static func singoliDocumentIndex(
        existingDocuments: [DocumentItem],
        restaurantId: UUID,
        interval: DateInterval,
        documentType: DocumentType
    ) -> [[PDFTableCell]] {
        let singles = existingDocuments.filter {
            $0.restaurantId == restaurantId
                && $0.type == documentType
                && DocumentArchiveLayout.isSingleModule($0.module)
                && ($0.periodStart.map { interval.contains($0) } ?? false)
        }
        .sorted {
            let l = DocumentArchiveLayout.moduleFolderTitle($0.module)
            let r = DocumentArchiveLayout.moduleFolderTitle($1.module)
            if l == r { return ($0.periodStart ?? .distantPast) < ($1.periodStart ?? .distantPast) }
            return l < r
        }

        let rows: [[PDFTableCell]] = singles.map { doc in
            [
                .text(DocumentArchiveLayout.moduleFolderTitle(doc.module)),
                .text(doc.officialDocumentId.isEmpty ? doc.id.uuidString : doc.officialDocumentId),
                .text(doc.fileName)
            ]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—")]] : rows
    }

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
        let activeModules = Set(DocumentArchiveLayout.activeMonthlyGenerationModules)
        let monthlies = existingDocuments.filter {
            $0.restaurantId == restaurantId
                && $0.type == .mensile
                && activeModules.contains($0.module)
                && ($0.periodStart.map { interval.contains($0) } ?? false)
        }
        .sorted {
            let l = DocumentArchiveLayout.moduleFolderTitle($0.module)
            let r = DocumentArchiveLayout.moduleFolderTitle($1.module)
            if l == r { return ($0.periodStart ?? .distantPast) < ($1.periodStart ?? .distantPast) }
            return l < r
        }

        let rows: [[PDFTableCell]] = monthlies.compactMap { doc in
            guard doc.periodStart != nil else { return nil }
            return [
                .text(DocumentArchiveLayout.moduleFolderTitle(doc.module)),
                .text(doc.officialDocumentId.isEmpty ? doc.id.uuidString : doc.officialDocumentId),
                .text(doc.fileName)
            ]
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
        let filtered = logs.filter {
            traceabilityIds.contains($0.receivedItemId)
                && interval.contains($0.timestamp)
                && ($0.actionType == .expired || $0.actionType == .rejected || $0.actionType == .nonCompliance || $0.actionType == .withdrawn)
        }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(40)
        let rows: [[PDFTableCell]] = filtered.map { log in
            let action: String = switch log.actionType {
            case .expired: "Scadenza"
            case .rejected: "Respinto"
            case .nonCompliance: "Non conformità"
            case .withdrawn: "Ritiro / scarto"
            default: "Evento"
            }
            return [.text(df.string(from: log.timestamp)), .text(log.operatorName), .text(action), .text(log.detail ?? String(log.receivedItemId.uuidString.prefix(8)).uppercased())]
        }
        return rows.isEmpty ? [[.text(HACCPRegisterCopy.noActivityInPeriod), .text("—"), .text("—"), .text("—")]] : rows
    }
}
