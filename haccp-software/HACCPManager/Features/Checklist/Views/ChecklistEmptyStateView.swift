import SwiftUI

struct ChecklistEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        DashboardEmptyStateView(state: .init(
            title: title,
            message: message,
            actionTitle: actionTitle
        )) {
            action?()
        }
    }
}
