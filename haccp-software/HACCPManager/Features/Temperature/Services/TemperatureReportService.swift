import Foundation
import SwiftData
import UIKit
import UserNotifications

struct TemperatureReportFile: Identifiable {
    let id = UUID()
    let url: URL
    let type: String
}

@MainActor
final class TemperatureReportService {
    private let calendar = Calendar.current
    private let outputDirName = "TemperatureReports"

    func generateReport(
        restaurant: Restaurant,
        records: [TemperatureRecord],
        devices: [TemperatureDevice],
        startDate: Date,
        endDate: Date,
        includeCSV: Bool,
        modelContext: ModelContext
    ) throws -> [TemperatureReportFile] {
        let outputDir = try ensureOutputDirectory()
        let periodLabel = dateLabel(startDate) + "_" + dateLabel(endDate)
        let pdfURL = outputDir.appendingPathComponent("temperature_report_\(periodLabel).pdf")

        try buildPDF(
            at: pdfURL,
            restaurantName: restaurant.name,
            devices: devices,
            records: records
        )

        var files: [TemperatureReportFile] = [.init(url: pdfURL, type: "PDF")]
        if includeCSV {
            let csvURL = outputDir.appendingPathComponent("temperature_report_\(periodLabel).csv")
            try buildCSV(at: csvURL, records: records)
            files.append(.init(url: csvURL, type: "CSV"))
        }

        for record in records {
            record.isArchived = true
        }
        try modelContext.save()

        scheduleReadyNotification()
        try cleanupOldExportFiles()
        return files
    }

    private func buildCSV(at url: URL, records: [TemperatureRecord]) throws {
        var csv = "device,temperature,unit,measured_at,user,status,min,max,notes,corrective_action\n"
        let formatter = ISO8601DateFormatter()

        for row in records.sorted(by: { $0.measuredAt < $1.measuredAt }) {
            let line = [
                escapeCSV(row.deviceName),
                "\(row.value)",
                row.unit.rawValue,
                formatter.string(from: row.measuredAt),
                escapeCSV(row.measuredByName),
                row.status.rawValue,
                "\(row.minAllowed)",
                "\(row.maxAllowed)",
                escapeCSV(row.notes ?? ""),
                escapeCSV(row.correctiveAction ?? "")
            ].joined(separator: ",")
            csv.append(line + "\n")
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private func buildPDF(
        at url: URL,
        restaurantName: String,
        devices: [TemperatureDevice],
        records: [TemperatureRecord]
    ) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595) // A4 landscape-ish
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            let margin: CGFloat = 24
            let tableStartX: CGFloat = margin
            let tableWidth: CGFloat = pageRect.width - (margin * 2)
            let headerHeight: CGFloat = 98
            let tableHeaderHeight: CGFloat = 28
            let rowHeight: CGFloat = 24
            let footerHeight: CGFloat = 18

            let columnRatios: [CGFloat] = [0.2, 0.1, 0.12, 0.14, 0.12, 0.17, 0.15]
            let columnTitles = ["Dispositivo", "Valore", "Range", "Stato", "Operatore", "Data/Ora", "Azione correttiva"]
            let totalRatio = columnRatios.reduce(0, +)
            let columnWidths = columnRatios.map { tableWidth * ($0 / totalRatio) }

            let sorted = records.sorted(by: { $0.measuredAt < $1.measuredAt })
            let pages = max(1, Int(ceil(Double(sorted.count) / Double(maxRowsPerPage(
                pageHeight: pageRect.height,
                headerHeight: headerHeight,
                tableHeaderHeight: tableHeaderHeight,
                rowHeight: rowHeight,
                footerHeight: footerHeight,
                margin: margin
            )))))

            var pageIndex = 0
            var rowIndex = 0
            let rowsPerPage = maxRowsPerPage(
                pageHeight: pageRect.height,
                headerHeight: headerHeight,
                tableHeaderHeight: tableHeaderHeight,
                rowHeight: rowHeight,
                footerHeight: footerHeight,
                margin: margin
            )

            repeat {
                context.beginPage()
                pageIndex += 1

                let headerFrame = CGRect(x: margin, y: margin, width: tableWidth, height: headerHeight)
                drawReportHeader(
                    in: headerFrame,
                    restaurantName: restaurantName,
                    devices: devices,
                    page: pageIndex,
                    totalPages: pages
                )

                var currentY = margin + headerHeight + 8
                let tableHeaderFrame = CGRect(x: tableStartX, y: currentY, width: tableWidth, height: tableHeaderHeight)
                drawTableHeader(
                    in: tableHeaderFrame,
                    titles: columnTitles,
                    widths: columnWidths
                )
                currentY += tableHeaderHeight

                var rowsDrawn = 0
                while rowsDrawn < rowsPerPage, rowIndex < sorted.count {
                    let record = sorted[rowIndex]
                    let rowFrame = CGRect(x: tableStartX, y: currentY, width: tableWidth, height: rowHeight)
                    drawTableRow(
                        in: rowFrame,
                        record: record,
                        widths: columnWidths,
                        index: rowIndex
                    )
                    rowsDrawn += 1
                    rowIndex += 1
                    currentY += rowHeight
                }

                let footerText = "Documento HACCP - Registro temperature locale - Generato automaticamente"
                footerText.draw(
                    in: CGRect(x: margin, y: pageRect.height - margin - footerHeight, width: tableWidth, height: footerHeight),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.gray
                    ]
                )
            } while rowIndex < sorted.count
        }
    }

    private func drawReportHeader(
        in frame: CGRect,
        restaurantName: String,
        devices: [TemperatureDevice],
        page: Int,
        totalPages: Int
    ) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]

        UIColor(white: 0.97, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: frame, cornerRadius: 10).fill()

        UIColor(red: 0.77, green: 0.06, blue: 0.13, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: CGRect(x: frame.maxX - 140, y: frame.minY + 12, width: 120, height: 22), cornerRadius: 6).fill()
        "TEMPERATURE REPORT".draw(
            in: CGRect(x: frame.maxX - 134, y: frame.minY + 16, width: 108, height: 16),
            withAttributes: badgeAttributes
        )

        "Registro Temperature HACCP".draw(
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 12),
            withAttributes: titleAttributes
        )
        "Ristorante: \(restaurantName)".draw(
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 42),
            withAttributes: subtitleAttributes
        )
        "Dispositivi: \(devices.map(\.name).joined(separator: ", "))".draw(
            in: CGRect(x: frame.minX + 14, y: frame.minY + 58, width: frame.width - 28, height: 20),
            withAttributes: subtitleAttributes
        )
        "Generato: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))".draw(
            at: CGPoint(x: frame.minX + 14, y: frame.minY + 76),
            withAttributes: subtitleAttributes
        )
        "Pagina \(page) / \(totalPages)".draw(
            at: CGPoint(x: frame.maxX - 120, y: frame.minY + 76),
            withAttributes: subtitleAttributes
        )
    }

    private func drawTableHeader(in frame: CGRect, titles: [String], widths: [CGFloat]) {
        UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).setFill()
        UIRectFill(frame)
        UIColor.black.setStroke()
        UIRectFrame(frame)

        var x = frame.minX
        for (idx, title) in titles.enumerated() {
            let width = widths[idx]
            let cell = CGRect(x: x, y: frame.minY, width: width, height: frame.height)
            UIColor.black.setStroke()
            UIRectFrame(cell)
            title.draw(
                in: cell.insetBy(dx: 6, dy: 6),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: UIColor.white
                ]
            )
            x += width
        }
    }

    private func drawTableRow(in frame: CGRect, record: TemperatureRecord, widths: [CGFloat], index: Int) {
        (index % 2 == 0 ? UIColor.white : UIColor(white: 0.98, alpha: 1.0)).setFill()
        UIRectFill(frame)
        UIColor(white: 0.85, alpha: 1.0).setStroke()
        UIRectFrame(frame)

        let rowValues = [
            record.deviceName,
            String(format: "%.1f C", record.value),
            String(format: "%.1f / %.1f", record.minAllowed, record.maxAllowed),
            record.status.rawValue,
            record.measuredByName,
            DateFormatter.localizedString(from: record.measuredAt, dateStyle: .short, timeStyle: .short),
            record.correctiveAction?.isEmpty == false ? record.correctiveAction! : "-"
        ]

        var x = frame.minX
        for idx in 0..<widths.count {
            let width = widths[idx]
            let cell = CGRect(x: x, y: frame.minY, width: width, height: frame.height)
            UIColor(white: 0.85, alpha: 1.0).setStroke()
            UIRectFrame(cell)

            let color: UIColor = idx == 3 ? statusColor(record.status) : .black
            let rowTextAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: color
            ]
            rowValues[idx].draw(
                in: cell.insetBy(dx: 6, dy: 5),
                withAttributes: rowTextAttributes
            )
            x += width
        }
    }

    private func statusColor(_ status: TemperatureStatus) -> UIColor {
        switch status {
        case .ok: return UIColor(red: 0.0, green: 0.54, blue: 0.18, alpha: 1.0)
        case .warning: return UIColor(red: 0.79, green: 0.55, blue: 0.0, alpha: 1.0)
        case .outOfRange: return UIColor(red: 0.76, green: 0.11, blue: 0.16, alpha: 1.0)
        case .critical: return UIColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0)
        }
    }

    private func maxRowsPerPage(
        pageHeight: CGFloat,
        headerHeight: CGFloat,
        tableHeaderHeight: CGFloat,
        rowHeight: CGFloat,
        footerHeight: CGFloat,
        margin: CGFloat
    ) -> Int {
        let usable = pageHeight - (margin * 2) - headerHeight - tableHeaderHeight - footerHeight - 8
        return max(1, Int(floor(usable / rowHeight)))
    }

    private func escapeCSV(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func ensureOutputDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(outputDirName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func scheduleReadyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Report pronto"
        content.body = "Il report temperature e stato generato."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cleanupOldExportFiles() throws {
        let dir = try ensureOutputDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        let thresholdDate = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date.distantPast

        for file in urls {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values.contentModificationDate, modified < thresholdDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
