import SwiftUI
import SwiftData

struct SchedulingView: View {
    @EnvironmentObject var appState: AppState
    @Query private var tasks: [ScheduledTask]
    @StateObject private var vm = SchedulingViewModel()

    private var scopedTasks: [ScheduledTask] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return tasks.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Programmazione") {
                if scopedTasks.isEmpty {
                    DashboardEmptyStateView(state: .init(
                        title: "Nessuna attivita programmata",
                        message: "Le attivita giornaliere, settimanali e mensili appariranno qui.",
                        actionTitle: nil
                    ))
                } else {
                    VStack(spacing: 10) {
                        ForEach(scopedTasks.prefix(30)) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title).foregroundColor(.white)
                                    Text(task.frequency.rawValue).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(task.isCompleted ? "Completata" : "Da fare")
                                    .font(.caption.bold())
                                    .foregroundColor(task.isCompleted ? .green : .yellow)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Programmazione")
    }
}
