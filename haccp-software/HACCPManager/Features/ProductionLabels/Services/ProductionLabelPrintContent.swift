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

    // MARK: - Righe stampa fisica

    static func printLines(
        for label: ProductionLabelRecord,
        settings: LabelPrinterSettings,
        restaurantName: String? = nil
    ) -> [PrintLine] {
        let profile = settings.labelSpec.layout
        var lines: [PrintLine] = []

        lines.append(.init(id: "brand", text: "HACCP", fontSize: profile.brandFontSize, bold: true, priority: 200))

        if settings.showProductName {
            lines.append(.init(
                id: "product",
                text: LabelStickerText.fit(label.productName.uppercased(), maxLength: profile.productNameMaxLength),
                fontSize: profile.productFontSize,
                bold: true,
                priority: 190
            ))
        }
        if settings.showExpiryDate {
            let d = label.expiryDate.formatted(date: .abbreviated, time: .omitted)
            lines.append(.init(id: "expiry", text: "Scad. \(d)", fontSize: profile.detailFontSize, bold: false, priority: 180))
        }
        if settings.showLotNumber, let lot = label.lotCode?.trimmingCharacters(in: .whitespacesAndNewlines), !lot.isEmpty {
            lines.append(.init(
                id: "lot",
                text: "Lotto \(LabelStickerText.fit(lot, maxLength: profile.detailMaxLength - 6))",
                fontSize: profile.detailFontSize,
                bold: false,
                priority: 170
            ))
        }
        if settings.showPrepDate {
            let d = label.productionDate.formatted(date: .abbreviated, time: .omitted)
            lines.append(.init(id: "prod", text: "Prod. \(d)", fontSize: profile.detailFontSize, bold: false, priority: 160))
        }
        if settings.showAllergenWarning, !label.allergenList.isEmpty {
            let text = label.allergenList.joined(separator: ", ")
            lines.append(.init(
                id: "allergens",
                text: "All: \(LabelStickerText.fit(text, maxLength: profile.detailMaxLength - 5))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 150
            ))
        }
        if settings.showOperatorName {
            let op = LabelStickerText.fit(label.createdByNameSnapshot, maxLength: profile.detailMaxLength - 4)
            lines.append(.init(id: "operator", text: "Op. \(op)", fontSize: profile.smallFontSize, bold: false, priority: 140))
        }
        if let supplier = label.supplier?.trimmingCharacters(in: .whitespacesAndNewlines), !supplier.isEmpty {
            lines.append(.init(
                id: "supplier",
                text: "Forn. \(LabelStickerText.fit(supplier, maxLength: profile.detailMaxLength - 6))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 130
            ))
        }
        if let category = label.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            lines.append(.init(
                id: "category",
                text: "Cat. \(LabelStickerText.fit(category, maxLength: profile.detailMaxLength - 5))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 120
            ))
        }
        if let qty = label.quantityDisplay {
            lines.append(.init(
                id: "quantity",
                text: "Qtà \(LabelStickerText.fit(qty, maxLength: profile.detailMaxLength - 4))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 110
            ))
        }
        if let temp = label.temperatureNote?.trimmingCharacters(in: .whitespacesAndNewlines), !temp.isEmpty {
            lines.append(.init(
                id: "temperature",
                text: "Temp. \(LabelStickerText.fit(temp, maxLength: profile.detailMaxLength - 6))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 100
            ))
        }
        if let storage = label.storageInstructions?.trimmingCharacters(in: .whitespacesAndNewlines), !storage.isEmpty {
            lines.append(.init(
                id: "storage",
                text: "Cons. \(LabelStickerText.fit(storage, maxLength: profile.detailMaxLength - 6))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 90
            ))
        }
        let status = label.productStatus.label
        if !status.isEmpty {
            lines.append(.init(
                id: "status",
                text: "Stato: \(LabelStickerText.fit(status, maxLength: profile.detailMaxLength - 7))",
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 80
            ))
        }
        if let notes = label.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            lines.append(.init(
                id: "notes",
                text: LabelStickerText.fit(notes, maxLength: profile.detailMaxLength),
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 70
            ))
        }
        if let restaurant = restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines), !restaurant.isEmpty {
            lines.append(.init(
                id: "restaurant",
                text: LabelStickerText.fit(restaurant, maxLength: profile.detailMaxLength),
                fontSize: profile.smallFontSize,
                bold: false,
                priority: 60
            ))
        }

        return lines
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
            guard remaining > 4 else { break }
            let bounding = (line.text as NSString).boundingRect(
                with: CGSize(width: maxTextWidth, height: remaining),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: [.font: font],
                context: nil
            )
            let used = min(max(bounding.height, font.lineHeight), remaining) + lineGap
            if y + used > maxHeight - padding {
                if line.priority >= 150 { fitted.append(line) }
                continue
            }
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

    private static func appendHumanRow(_ rows: inout [String], key: String, value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        rows.append("\(key): \(trimmed)")
    }

    private static func shortDay(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
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
