import Foundation

struct TemperatureChartPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let minAllowed: Double
    let maxAllowed: Double
    let isOutOfRange: Bool
}
