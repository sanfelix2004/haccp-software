import Foundation
import SwiftData
import Combine

@MainActor
final class TemperatureDashboardViewModel: ObservableObject {
    @Published var selectedTab: TemperatureTab = .dashboard
    @Published var showAddRecordSheet = false
    @Published var showAddDeviceSheet = false
    @Published var selectedDevice: TemperatureDevice?
    @Published var reportFiles: [TemperatureReportFile] = []
    @Published var reportError: String?
    @Published var reportReadyMessage: String?

    let moduleService = TemperatureModuleService()
    let reportService = TemperatureReportService()

    func problematicDevices(records: [TemperatureRecord]) -> [UUID: TemperatureStatus] {
        var latestByDevice: [UUID: TemperatureRecord] = [:]
        for record in records.sorted(by: { $0.measuredAt > $1.measuredAt }) {
            if latestByDevice[record.deviceId] == nil {
                latestByDevice[record.deviceId] = record
            }
        }

        return latestByDevice.reduce(into: [:]) { partial, item in
            partial[item.key] = item.value.status
        }
    }

    func recentRecords(_ records: [TemperatureRecord], limit: Int = 100) -> [TemperatureRecord] {
        Array(records.sorted(by: { $0.measuredAt > $1.measuredAt }).prefix(limit))
    }

    func paginatedHistory(_ records: [TemperatureRecord], page: Int, pageSize: Int) -> [TemperatureRecord] {
        let sorted = records.sorted(by: { $0.measuredAt > $1.measuredAt })
        let start = page * pageSize
        guard start < sorted.count else { return [] }
        let end = min(start + pageSize, sorted.count)
        return Array(sorted[start..<end])
    }

    func exportReport(
        restaurant: Restaurant,
        records: [TemperatureRecord],
        devices: [TemperatureDevice],
        startDate: Date,
        endDate: Date,
        includeCSV: Bool,
        modelContext: ModelContext
    ) {
        do {
            let files = try reportService.generateReport(
                restaurant: restaurant,
                records: records,
                devices: devices,
                startDate: startDate,
                endDate: endDate,
                includeCSV: includeCSV,
                modelContext: modelContext
            )
            reportFiles = files
            reportReadyMessage = "Report pronto"
            reportError = nil
        } catch {
            reportError = "Generazione report fallita: \(error.localizedDescription)"
        }
    }
}

enum TemperatureTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case devices = "Dispositivi"
    case history = "Storico"
    case alerts = "Alert"

    var id: String { rawValue }
}
