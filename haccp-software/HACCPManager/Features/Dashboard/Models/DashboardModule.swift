import Foundation
import SwiftUI

enum DashboardModuleState: String {
    case configure = "Da configurare"
    case open = "Apri modulo"

    var tint: Color {
        switch self {
        case .configure: return Color.white.opacity(0.75)
        case .open: return .red
        }
    }
}

struct DashboardModule: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let state: DashboardModuleState
    let isEnabled: Bool
}
