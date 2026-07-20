import Foundation

/// Esportazione CSV testuale dai registri (senza immagini inline; colonna foto = Sì/No).
enum HACCPRegisterCSVExporter {
    private static func df() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    static func csvString(
        for item: DocumentItem,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        calendar: Calendar
    ) -> String? {
        guard let interval = intervalForItem(item, calendar: calendar) else { return nil }
        let formatter = df()

        switch item.module {
        case .ricezioneMerci:
            return csvRicezione(interval: interval, receipts: receipts, df: formatter)
        case .tracciabilita:
            return csvTracciabilita(
                interval: interval,
                records: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                df: formatter
            )
        case .combinatoTracciabilitaProduzione, .etichetteProduzione, .controlloScadenze:
            return csvTracciabilitaProduzioni(
                interval: interval,
                records: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                df: formatter
            )
        case .haccpCombinato:
            return csvCombinato(
                interval: interval,
                receipts: receipts,
                traceability: traceability,
                images: images,
                productions: productions,
                links: links,
                logs: logs,
                df: formatter
            )
        case .nonConformita:
            return csvNonConformita(interval: interval, receipts: receipts, traceability: traceability, images: images, df: formatter)
        default:
            return "Messaggio\n\(makeLine([HACCPRegisterCopy.noActivityInPeriod]))"
        }
    }

    private static func intervalForItem(_ item: DocumentItem, calendar: Calendar) -> DateInterval? {
        guard let start = item.periodStart else { return nil }
        let effectiveType: DocumentType = (item.type == .mensile && item.module == .nonConformita) ? .nonConformita : item.type
        switch effectiveType {
        case .giornaliero:
            let d = calendar.startOfDay(for: start)
            let end = calendar.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
            return DateInterval(start: d, end: end)
        case .mensile, .nonConformita:
            return calendar.dateInterval(of: .month, for: start)
        case .annuale:
            return calendar.dateInterval(of: .year, for: start)
        default:
            let d = calendar.startOfDay(for: start)
            let end = calendar.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
            return DateInterval(start: d, end: end)
        }
    }

    private static func csvRicezione(interval: DateInterval, receipts: [GoodsReceipt], df: DateFormatter) -> String {
        let rows = GoodsReceiptRegister.rows(in: interval, receipts: receipts, df: df)
        var lines: [String] = []
        lines.append(makeLine([
            "Prodotto", "Categoria", "Fornitore", "Lotto", "Scadenza", "Temp. rilevata",
            "Esito temp.", "Conformità", "Checklist", "Note", "Operatore", "Data/ora ricezione"
        ]))
        for r in rows {
            lines.append(makeLine([
                r.product, r.category, r.supplier, r.lot, r.expiry, r.temperatureRead,
                r.temperatureOutcome, r.conformity, r.checklist, r.notes, r.operatorName, r.receivedAt
            ]))
        }
        if rows.isEmpty { lines.append(escapeRow([HACCPRegisterCopy.noActivityInPeriod])) }
        return lines.joined(separator: "\n")
    }

    private static func csvTracciabilita(
        interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        df: DateFormatter
    ) -> String {
        let rows = TraceabilityRegister.rows(
            in: interval,
            records: records,
            productions: productions,
            links: links,
            logs: logs,
            images: images,
            df: df
        )
        var lines: [String] = []
        lines.append(makeLine([
            "Prodotto", "Lotto", "Fornitore / origine", "Creato il", "Registrato da",
            "Associato a (quando / da chi)", "Chiusura (esito · quando · chi)", "Stato", "Note NC"
        ]))
        for r in rows {
            lines.append(makeLine([
                r.product, r.lot, r.supplier, r.createdAt, r.createdBy,
                r.associations, r.closure, r.status, r.nonCompliance
            ]))
        }
        if rows.isEmpty { lines.append(escapeRow([HACCPRegisterCopy.noActivityInPeriod])) }
        return lines.joined(separator: "\n")
    }

    private static func csvTracciabilitaProduzioni(
        interval: DateInterval,
        records: [TraceabilityRecord],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        images: [ProductImage],
        df: DateFormatter
    ) -> String {
        [
            "TRACCIABILITA_E_PRODUZIONI",
            csvTracciabilita(
                interval: interval,
                records: records,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                df: df
            )
        ].joined(separator: "\n")
    }

    private static func csvNonConformita(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        df: DateFormatter
    ) -> String {
        let rows = NonConformityRegister.rows(
            in: interval,
            receipts: receipts,
            traceability: traceability,
            images: images,
            df: df
        )
        var lines: [String] = []
        lines.append(makeLine([
            "Prodotto", "Lotto", "Motivo", "Azione correttiva", "Stato", "Risolta da", "Risolta il",
            "Data rilevazione", "Operatore", "Origine"
        ]))
        for r in rows {
            lines.append(makeLine([
                r.product, r.lot, r.reason, r.correctiveAction, r.stato, r.risoltaDa, r.risoltaIl,
                r.date, r.operatorName, r.source
            ]))
        }
        if rows.isEmpty { lines.append(escapeRow([HACCPRegisterCopy.noActivityInPeriod])) }
        return lines.joined(separator: "\n")
    }

    private static func csvCombinato(
        interval: DateInterval,
        receipts: [GoodsReceipt],
        traceability: [TraceabilityRecord],
        images: [ProductImage],
        productions: [Production],
        links: [TraceabilityLink],
        logs: [TraceabilityLog],
        df: DateFormatter
    ) -> String {
        [
            "RICEZIONE_MERCI",
            csvRicezione(interval: interval, receipts: receipts, df: df),
            "",
            "TRACCIABILITA",
            csvTracciabilita(
                interval: interval,
                records: traceability,
                productions: productions,
                links: links,
                logs: logs,
                images: images,
                df: df
            ),
            "",
            "NON_CONFORMITA",
            csvNonConformita(interval: interval, receipts: receipts, traceability: traceability, images: images, df: df)
        ].joined(separator: "\n")
    }

    private static func makeLine(_ fields: [String]) -> String {
        fields.map { escapeField($0) }.joined(separator: ";")
    }

    private static func escapeRow(_ fields: [String]) -> String {
        makeLine(fields)
    }

    private static func escapeField(_ s: String) -> String {
        if s.contains(";") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
