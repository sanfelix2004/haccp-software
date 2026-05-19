import SwiftUI

struct DashboardRecentActivitySection: View {
    let activities: [DashboardRecentActivity]

    var body: some View {
        DashboardCardView(title: DashboardSection.recentActivities.rawValue) {
            if activities.isEmpty {
                DashboardEmptyStateView(
                    state: DashboardEmptyState(
                        title: "Nessuna attivita registrata",
                        message: "Le attivita recenti appariranno qui quando saranno disponibili",
                        actionTitle: nil
                    )
                )
            } else {
                ForEach(activities) { activity in
                    HStack {
                        Text(activity.userName)
                            .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                        Spacer()
                        Text(activity.action)
                            .foregroundColor(ThemeManager.shared.colorTextSecondary)
                    }
                }
            }
        }
    }
}
