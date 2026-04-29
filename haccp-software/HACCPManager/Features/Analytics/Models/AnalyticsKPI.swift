import SwiftUI

struct AnalyticsKPI: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let color: Color
}
