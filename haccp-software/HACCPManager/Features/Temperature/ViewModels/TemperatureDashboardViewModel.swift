import Foundation
import SwiftData
import Combine

@MainActor
final class TemperatureDashboardViewModel: ObservableObject {
    @Published var selectedTab: TemperatureTab = .dashboard
    @Published var showAddRecordSheet = false
    @Published var showAddDeviceSheet = false
    @Published var showDevicePickerSheet = false
    @Published var selectedDevice: TemperatureDevice?

    let moduleService = TemperatureModuleService()

    func latestRecord(for deviceId: UUID, in records: [TemperatureRecord]) -> TemperatureRecord? {
        records.filter { $0.deviceId == deviceId }.max(by: { $0.measuredAt < $1.measuredAt })
    }

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

    func records(
        _ all: [TemperatureRecord],
        matching range: TemperatureHistoryRange,
        now: Date = Date()
    ) -> [TemperatureRecord] {
        let start: Date? = {
            let calendar = Calendar.current
            switch range {
            case .today: return calendar.startOfDay(for: now)
            case .week: return calendar.date(byAdding: .day, value: -7, to: now)
            case .month: return calendar.date(byAdding: .day, value: -30, to: now)
            case .all: return nil
            }
        }()
        let sorted = all.sorted(by: { $0.measuredAt > $1.measuredAt })
        guard let start else { return sorted }
        return sorted.filter { $0.measuredAt >= start }
    }
}

enum TemperatureTab: String, CaseIterable, Identifiable {
    case dashboard = "Panoramica"
    case devices = "Frigoriferi"
    case history = "Storico"
    case alerts = "Avvisi"

    var id: String { rawValue }
}

enum TemperatureHistoryRange: String, CaseIterable, Identifiable {
    case today = "Oggi"
    case week = "7 giorni"
    case month = "30 giorni"
    case all = "Tutto"

    var id: String { rawValue }
}
