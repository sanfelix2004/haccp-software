import Foundation

struct ChecklistChartPoint: Identifiable {
    let id = UUID()
    let dayStart: Date
    let dayLabel: String
    let completionPercentage: Double
    let completedRuns: Int
    let overdueRuns: Int
    let criticalOpen: Int
}
