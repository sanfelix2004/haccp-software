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
        let pageRect = CGRect(x: 0, y: 0, width: 842, height: 595)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let title = "HACCP Temperature Report - \(restaurantName)"
            title.draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])

            let subtitle = "Generato: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
            subtitle.draw(at: CGPoint(x: 20, y: 44), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])

            var y: CGFloat = 76
            let deviceNames = devices.map(\.name).joined(separator: ", ")
            ("Dispositivi: " + deviceNames).draw(
                in: CGRect(x: 20, y: y, width: 800, height: 40),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
            y += 34

            for record in records.sorted(by: { $0.measuredAt < $1.measuredAt }) {
                if y > 545 {
                    context.beginPage()
                    y = 20
                }
                let line = "\(record.deviceName) | \(record.value)C | \(record.status.rawValue) | \(record.measuredByName) | \(DateFormatter.localizedString(from: record.measuredAt, dateStyle: .short, timeStyle: .short)) | Azione: \(record.correctiveAction ?? "-")"
                line.draw(
                    in: CGRect(x: 20, y: y, width: 800, height: 24),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11)]
                )
                y += 20
            }
        }
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
