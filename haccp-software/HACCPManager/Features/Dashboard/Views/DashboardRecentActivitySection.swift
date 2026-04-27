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
                            .foregroundColor(.white)
                        Spacer()
                        Text(activity.action)
                            .foregroundColor(Color.white.opacity(0.72))
                    }
                }
            }
        }
    }
}
