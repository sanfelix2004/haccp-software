import Foundation
import UIKit

/// Righe stampate sull'adesivo e testo QR leggibile da qualsiasi telefono (senza app).
enum ProductionLabelPrintContent {

    struct PrintLine: Identifiable {
        let id: String
        let text: String
        let fontSize: CGFloat
        let bold: Bool
        /// Più alto = più importante se lo spazio finisce.
        let priority: Int
    }

    // MARK: - Righe stampa fisica (50×30)

    static func printLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) -> [PrintLine] {
        _ = restaurantName
        return compactPrintLines(for: label, settings: settings)
    }

    /// Solo info essenziali, una per riga — layout diverso per abbattimento / decongelamento.
    private static func compactPrintLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings
    ) -> [PrintLine] {
        let profile = settings.labelSpec.layout
        let maxChars = min(18, profile.productNameMaxLength)

        let lines: [PrintLine]
        switch label.sourceModule {
        case .blastChilling, .production:
            lines = blastPrintLines(for: label, settings: settings, maxChars: maxChars, profile: profile)
        case .defrost:
            lines = defrostPrintLines(for: label, settings: settings, maxChars: maxChars, profile: profile)
        default:
            lines = productionPrintLines(for: label, settings: settings, maxChars: maxChars, profile: profile)
        }

        return Array(lines.prefix(profile.maxDetailLines)).map { line in
            PrintLine(
                id: line.id,
                text: printerSafe(line.text),
                fontSize: line.fontSize,
                bold: line.bold,
                priority: line.priority
            )
        }
    }

    /// Abbattimento: nome, data abb., scad, Ti/Tf, durata.
    private static func blastPrintLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) -> [PrintLine] {
        var lines: [PrintLine] = []

        if settings.showProductName {
            lines.append(.init(
                id: "product",
                text: LabelStickerText.printerFit(label.productName.uppercased(), maxLength: maxChars),
                fontSize: profile.productFontSize,
                bold: true,
                priority: 190
            ))
        }
        if settings.showPrepDate {
            lines.append(.init(
                id: "blast",
                text: LabelStickerText.printerFit("Abb. \(ultraShortDay(label.productionDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 180
            ))
        }
        if settings.showExpiryDate {
            lines.append(.init(
                id: "expiry",
                text: LabelStickerText.printerFit("Scad \(ultraShortDay(label.expiryDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 170
            ))
        }
        appendProcessTempDurationLines(
            to: &lines,
            temperatureNote: label.temperatureNote,
            maxChars: maxChars,
            profile: profile
        )
        appendOperatorLine(to: &lines, label: label, settings: settings, maxChars: maxChars, profile: profile)
        return lines
    }

    /// Decongelamento: nome, data dec., scad, Ti/Tf, durata.
    private static func defrostPrintLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) -> [PrintLine] {
        var lines: [PrintLine] = []

        if settings.showProductName {
            lines.append(.init(
                id: "product",
                text: LabelStickerText.printerFit(label.productName.uppercased(), maxLength: maxChars),
                fontSize: profile.productFontSize,
                bold: true,
                priority: 190
            ))
        }
        if settings.showPrepDate {
            lines.append(.init(
                id: "defrost",
                text: LabelStickerText.printerFit("Dec. \(ultraShortDay(label.productionDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 180
            ))
        }
        if settings.showExpiryDate {
            lines.append(.init(
                id: "expiry",
                text: LabelStickerText.printerFit("Scad \(ultraShortDay(label.expiryDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 170
            ))
        }
        appendProcessTempDurationLines(
            to: &lines,
            temperatureNote: label.temperatureNote,
            maxChars: maxChars,
            profile: profile
        )
        appendOperatorLine(to: &lines, label: label, settings: settings, maxChars: maxChars, profile: profile)
        return lines
    }

    /// Produzione / altri: nome, prod, scad, lotto, operatore.
    private static func productionPrintLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) -> [PrintLine] {
        var lines: [PrintLine] = []

        if settings.showProductName {
            lines.append(.init(
                id: "product",
                text: LabelStickerText.printerFit(label.productName.uppercased(), maxLength: maxChars),
                fontSize: profile.productFontSize,
                bold: true,
                priority: 190
            ))
        }
        // Lotto produzione: subito sotto il nome, in evidenza.
        if settings.showLotNumber,
           let lot = label.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lot.isEmpty {
            lines.append(.init(
                id: "lot",
                text: LabelStickerText.printerFit("LOTTO \(lot)", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: true,
                priority: 185
            ))
        }
        if settings.showExpiryDate {
            lines.append(.init(
                id: "expiry",
                text: LabelStickerText.printerFit("Scad \(ultraShortDay(label.expiryDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 180
            ))
        }
        if settings.showPrepDate {
            lines.append(.init(
                id: "prod",
                text: LabelStickerText.printerFit("Prod \(ultraShortDay(label.productionDate))", maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 170
            ))
        }
        appendAllergenLines(to: &lines, label: label, settings: settings, maxChars: maxChars, profile: profile)
        appendOperatorLine(to: &lines, label: label, settings: settings, maxChars: maxChars, profile: profile)
        return lines
    }

    private static func appendAllergenLines(
        to lines: inout [PrintLine],
        label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) {
        guard settings.showAllergenWarning else { return }
        let allergens = label.allergenList
        guard !allergens.isEmpty else { return }
        let joined = allergens.joined(separator: ", ").uppercased()
        lines.append(.init(
            id: "allergens",
            text: LabelStickerText.printerFit("ALL. \(joined)", maxLength: maxChars),
            fontSize: profile.detailFontSize,
            bold: true,
            priority: 155
        ))
    }

    private static func appendOperatorLine(
        to lines: inout [PrintLine],
        label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) {
        let op = label.createdByNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.showOperatorName, !op.isEmpty else { return }
        lines.append(.init(
            id: "operator",
            text: LabelStickerText.printerFit("Op. \(op)", maxLength: maxChars),
            fontSize: profile.smallFontSize,
            bold: false,
            priority: 140
        ))
    }

    private static func appendProcessTempDurationLines(
        to lines: inout [PrintLine],
        temperatureNote: String?,
        maxChars: Int,
        profile: ClabelLabelLayoutProfile
    ) {
        let fragments = ProcessLabelDetailNote.printFragments(from: temperatureNote)
        if fragments.isEmpty {
            if let temp = compactTemperature(temperatureNote) {
                lines.append(.init(
                    id: "temp",
                    text: LabelStickerText.printerFit("T \(temp)", maxLength: maxChars),
                    fontSize: profile.detailFontSize,
                    bold: false,
                    priority: 165
                ))
            }
            return
        }

        for (index, fragment) in fragments.enumerated() {
            let priority = 165 - index
            lines.append(.init(
                id: "process-\(index)",
                text: LabelStickerText.printerFit(printerSafe(fragment), maxLength: maxChars),
                fontSize: profile.detailFontSize,
                bold: false,
                priority: priority
            ))
        }
    }

    /// Es. " -18.0 C" / "-18C" per stampa termica.
    private static func compactTemperature(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        // Nuovo formato strutturato: non trattarlo come singola temperatura.
        if raw.localizedCaseInsensitiveContains("Ti") || raw.localizedCaseInsensitiveContains("Tf") {
            return nil
        }
        let cleaned = printerSafe(raw)
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.uppercased().hasSuffix("C") { return cleaned }
        return cleaned + "C"
    }

    /// Righe che entrano nell'altezza disponibile (stampa bitmap).
    static func fittingPrintLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String?,
        maxHeight: CGFloat,
        maxTextWidth: CGFloat
    ) -> [PrintLine] {
        let candidates = printLines(for: label, settings: settings, restaurantName: restaurantName)
        var y: CGFloat = 0
        var fitted: [PrintLine] = []
        let padding = settings.labelSpec.layout.contentPadding
        let lineGap = settings.labelSpec.layout.lineGap

        for line in candidates {
            let font = line.bold
                ? UIFont.boldSystemFont(ofSize: line.fontSize)
                : UIFont.systemFont(ofSize: line.fontSize)
            let remaining = maxHeight - y - padding
            guard remaining > font.lineHeight else { break }
            let bounding = (line.text as NSString).boundingRect(
                with: CGSize(width: maxTextWidth, height: remaining),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: [.font: font],
                context: nil
            )
            let used = max(bounding.height, font.lineHeight) + lineGap
            guard y + used <= maxHeight - padding + 0.5 else { break }
            fitted.append(line)
            y += used
        }
        return fitted
    }

    // MARK: - QR leggibile da telefono

    private static let humanMarker = "HACCP"

    static func humanReadableCandidates(
        for label: ProductionLabelRecord,
        restaurantName: String? = nil
    ) -> [String] {
        [
            buildHumanReadable(for: label, restaurantName: restaurantName, includeOptional: true),
            buildHumanReadable(for: label, restaurantName: restaurantName, includeOptional: false)
        ].filter { !$0.isEmpty }
    }

    static func buildHumanReadable(
        for label: ProductionLabelRecord,
        restaurantName: String? = nil,
        includeOptional: Bool = true
    ) -> String {
        var rows: [String] = [humanMarker]
        appendHumanRow(&rows, key: "Prodotto", value: label.productName)
        appendHumanRow(&rows, key: "Lotto", value: label.lotCode)
        appendHumanRow(&rows, key: "Prod", value: shortDay(label.productionDate))
        appendHumanRow(&rows, key: "Scad", value: shortDay(label.expiryDate))
        appendHumanRow(&rows, key: "Op", value: label.createdByNameSnapshot)

        if includeOptional {
            appendHumanRow(&rows, key: "Fornitore", value: label.supplier)
            appendHumanRow(&rows, key: "Categoria", value: label.category)
            appendHumanRow(&rows, key: "Qtà", value: label.quantityDisplay)
            appendHumanRow(&rows, key: "Temp", value: label.temperatureNote)
            appendHumanRow(&rows, key: "Conserv", value: label.storageInstructions)
            if !label.allergenList.isEmpty {
                appendHumanRow(&rows, key: "Allergeni", value: label.allergenList.joined(separator: ", "))
            }
            appendHumanRow(&rows, key: "Stato", value: label.productStatus.label)
            appendHumanRow(&rows, key: "Note", value: label.notes)
            appendHumanRow(&rows, key: "Locale", value: restaurantName)
        } else if !label.allergenList.isEmpty {
            appendHumanRow(&rows, key: "Allergeni", value: label.allergenList.joined(separator: ", "))
        }

        appendHumanRow(&rows, key: "ID", value: label.id.uuidString.uppercased())
        return rows.joined(separator: "\n")
    }

    static func parseHumanReadable(_ raw: String) -> ProductionLabelScanData? {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix(humanMarker) else { return nil }

        var fields: [String: String] = [:]
        let body = normalized.dropFirst(humanMarker.count).trimmingCharacters(in: .whitespacesAndNewlines)
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard let colon = text.firstIndex(of: ":") else { continue }
            let key = String(text[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            fields[key] = value
        }

        let id = fields["id"].flatMap { UUID(uuidString: $0) } ?? UUID()
        return ProductionLabelScanData(
            id: id,
            productName: fields["prodotto"] ?? "",
            productionDate: parseHumanDay(fields["prod"]),
            expiryDate: parseHumanDay(fields["scad"]),
            lotCode: fields["lotto"],
            operatorName: fields["op"],
            supplier: fields["fornitore"],
            category: fields["categoria"],
            allergens: fields["allergeni"],
            temperatureNote: fields["temp"],
            storageInstructions: fields["conserv"],
            quantityDisplay: fields["qtà"] ?? fields["qta"],
            productStatusLabel: fields["stato"],
            sourceModuleLabel: nil,
            notes: fields["note"],
            restaurantName: fields["locale"]
        )
    }

    // MARK: - Private

    /// Solo ASCII stampabile per TSPL CODEPAGE 1252 (niente ellissi/accenti → ideogrammi).
    static func printerSafe(_ text: String) -> String {
        let folded = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "℃", with: "C")
            .replacingOccurrences(of: "°C", with: "C")
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "\u{2026}", with: "")
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .applyingTransform(.stripDiacritics, reverse: false)
            ?? text

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .-_/#:+()")
        return String(folded.unicodeScalars.filter { allowed.contains($0) })
    }

    private static func appendHumanRow(_ rows: inout [String], key: String, value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        rows.append("\(key): \(trimmed)")
    }

    private static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
    }

    private static func ultraShortDay(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    private static func parseHumanDay(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formats = ["dd/MM/yy", "dd/MM/yyyy", "yyyy-MM-dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return HACCPDateNormalizer.dateFromDayString(value)
    }
}
