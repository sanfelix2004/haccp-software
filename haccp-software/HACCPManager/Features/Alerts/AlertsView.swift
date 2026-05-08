import SwiftUI
import SwiftData

struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var checklistAlerts: [ChecklistAlert]
    @Query private var temperatureAlerts: [TemperatureAlert]
    @Query private var cleaningCriticalities: [CleaningCriticality]
    @Query private var users: [LocalUser]

    private var activeChecklistAlerts: [ChecklistAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return checklistAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }

    private var activeTemperatureAlerts: [TemperatureAlert] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return temperatureAlerts.filter { $0.restaurantId == rid && $0.isActive }
    }

    private var activeCleaningCriticalities: [CleaningCriticality] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return cleaningCriticalities.filter { $0.restaurantId == rid && !$0.isResolved }
    }

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    var body: some View {
        ScrollView {
            DashboardCardView(title: "Alert") {
                if activeChecklistAlerts.isEmpty && activeTemperatureAlerts.isEmpty && activeCleaningCriticalities.isEmpty {
                    DashboardEmptyStateView(
                        state: DashboardEmptyState(
                            title: "Nessun alert attivo",
                            message: "Gli alert di temperatura, checklist e pulizie appariranno qui",
                            actionTitle: nil
                        )
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(activeChecklistAlerts) { alert in
                            alertRow(message: alert.message, date: alert.createdAt, icon: "checklist")
                        }
                        ForEach(activeTemperatureAlerts) { alert in
                            temperatureAlertRow(alert)
                        }
                        ForEach(activeCleaningCriticalities) { criticality in
                            cleaningAlertRow(criticality)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Alert")
    }

    private func alertRow(message: String, date: Date, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text(message).foregroundColor(.white)
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    private func cleaningAlertRow(_ criticality: CleaningCriticality) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Pulizia non conforme: \(criticality.areaName) · \(criticality.taskName)")
                    .foregroundColor(.white)
                Text("Azione: \(criticality.correctiveAction)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(criticality.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button("Segna risolta") {
                resolveCriticality(criticality)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    private func temperatureAlertRow(_ alert: TemperatureAlert) -> some View {
        HStack {
            Image(systemName: "thermometer.medium").foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Temperatura fuori range: \(alert.deviceName)")
                    .foregroundColor(.white)
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button("Risolvi") {
                resolveTemperatureAlert(alert)
            }
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    private func resolveCriticality(_ criticality: CleaningCriticality) {
        guard let user = currentUser else { return }
        criticality.isResolved = true
        criticality.resolvedAt = Date()
        criticality.resolvedByUserId = user.id
        criticality.resolvedByNameSnapshot = user.name
        try? modelContext.save()
    }

    private func resolveTemperatureAlert(_ alert: TemperatureAlert) {
        guard let user = currentUser, let rid = appState.activeRestaurantId else { return }
        do {
            try TemperatureModuleService().resolveAlert(
                alert,
                user: user,
                restaurantId: rid,
                modelContext: modelContext
            )
        } catch {
            alert.isActive = false
            alert.resolvedAt = Date()
            try? modelContext.save()
        }
    }
}
