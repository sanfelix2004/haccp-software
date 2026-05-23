//
//  ProductionLabelsView.swift
//  Modulo enterprise etichette HACCP.
//

import SwiftUI
import SwiftData

struct ProductionLabelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]

    @StateObject private var vm = ProductionLabelsViewModel()
    @StateObject private var dataStore = ProductionLabelsDataStore()

    @State private var showCreateManual = false
    @State private var showSourcePicker = false
    @State private var sourceDraft: ProductionLabelDraft?
    @State private var selectedLabelId: UUID?
    @ObservedObject private var printQueue = ProductionLabelPrintQueue.shared
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
    }

    private var filteredLabels: [ProductionLabelRecord] {
        vm.filteredLabels(from: dataStore.labels)
    }

    private var stats: (today: Int, expiringSoon: Int, active: Int) {
        vm.stats(from: dataStore.labels.filter { !$0.isArchived })
    }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                emptyRestaurantState
            } else if dataStore.isLoading && dataStore.labels.isEmpty {
                ProgressView("Caricamento etichette…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle("Etichette di produzione")
        .task(id: appState.activeRestaurantId) {
            reloadData()
        }
        .onChange(of: vm.appliedFilter.showArchived) { _, _ in
            reloadData()
        }
        .navigationDestination(item: $selectedLabelId) { labelId in
            if let label = dataStore.labels.first(where: { $0.id == labelId }),
               let user = currentUser {
                ProductionLabelDetailView(
                    label: label,
                    restaurantName: activeRestaurant?.name ?? "Ristorante",
                    user: user,
                    onChanged: { reloadData() }
                )
            }
        }
        .sheet(isPresented: $showCreateManual) {
            if let rid = appState.activeRestaurantId, let user = currentUser {
                ProductionLabelEditorSheet(
                    mode: .create(ProductionLabelDraft()),
                    restaurantId: rid,
                    user: user,
                    onSaved: {
                        showCreateManual = false
                        reloadData()
                    },
                    onCancel: { showCreateManual = false }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { sourceDraft != nil },
            set: { if !$0 { sourceDraft = nil } }
        )) {
            if let draft = sourceDraft,
               let rid = appState.activeRestaurantId,
               let user = currentUser {
                ProductionLabelEditorSheet(
                    mode: .create(draft),
                    restaurantId: rid,
                    user: user,
                    onSaved: {
                        sourceDraft = nil
                        reloadData()
                    },
                    onCancel: { sourceDraft = nil }
                )
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            ProductionLabelSourcePickerSheet(
                dataStore: dataStore,
                onSelect: { draft in
                    showSourcePicker = false
                    sourceDraft = draft
                },
                onCancel: { showSourcePicker = false }
            )
        }
        .sheet(isPresented: $showShare, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ProductionLabelShareSheet(url: shareURL)
            }
        }
        .alert("Etichette", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                statsRow

                DashboardCardView(title: "Azioni rapide", subtitle: "Crea etichette HACCP collegate ai moduli") {
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Nuova etichetta manuale", icon: "plus.circle.fill") {
                            showCreateManual = true
                        }
                        SecondaryButton(title: "Da tracciabilità / ricezione / abbattimento", icon: "link") {
                            showSourcePicker = true
                        }
                        if !filteredLabels.isEmpty {
                            SecondaryButton(title: "Esporta PDF archivio filtrato", icon: "doc.richtext") {
                                exportFilteredPDF()
                            }
                        }
                    }
                }

                if printQueue.pendingJobs.isEmpty == false {
                    DashboardCardView(title: "Coda stampa", subtitle: "Pronta per Bluetooth (in arrivo)") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(printQueue.pendingJobs) { job in
                                HStack {
                                    Image(systemName: "printer")
                                        .foregroundStyle(theme.colorInfo)
                                    Text("Etichetta in attesa · \(job.copies) copie")
                                        .font(theme.typography.subheadline)
                                    Spacer()
                                }
                            }
                            Text("La stampa termica sarà disponibile in un aggiornamento futuro.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                        }
                    }
                }

                DashboardCardView(
                    title: vm.appliedFilter.showArchived ? "Archivio etichette" : "Etichette attive",
                    subtitle: "\(filteredLabels.count) risultati"
                ) {
                    ProductionLabelFilterBar(filter: $vm.filter, labels: dataStore.labels)

                    if filteredLabels.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna etichetta",
                            message: "Crea la prima etichetta HACCP per identificare prodotti, lotti e scadenze in cucina.",
                            actionTitle: "Nuova etichetta"
                        )) {
                            showCreateManual = true
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredLabels.prefix(80)) { label in
                                Button {
                                    selectedLabelId = label.id
                                } label: {
                                    ProductionLabelRowView(label: label)
                                }
                                .buttonStyle(PremiumPressButtonStyle())
                            }
                            if filteredLabels.count > 80 {
                                Text("Mostrati i primi 80 risultati. Affina i filtri per trovare altro.")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Oggi",
                value: "\(stats.today)",
                subtitle: "Create oggi",
                icon: "tag.fill",
                accent: theme.colorPrimary
            )
            StatCard(
                title: "In scadenza",
                value: "\(stats.expiringSoon)",
                subtitle: "Entro 3 giorni",
                icon: "clock.badge.exclamationmark",
                accent: stats.expiringSoon > 0 ? theme.colorWarning : theme.colorTextSecondary
            )
            StatCard(
                title: "Attive",
                value: "\(stats.active)",
                subtitle: "In uso",
                icon: "checkmark.seal.fill",
                accent: theme.colorSuccess
            )
        }
    }

    private var emptyRestaurantState: some View {
        DashboardEmptyStateView(state: .init(
            title: "Seleziona un ristorante",
            message: "Le etichette HACCP sono associate al ristorante attivo.",
            actionTitle: nil
        ))
        .padding(24)
    }

    private func reloadData() {
        dataStore.reload(
            context: modelContext,
            restaurantId: appState.activeRestaurantId,
            includeArchived: vm.appliedFilter.showArchived
        )
    }

    private func exportFilteredPDF() {
        guard let name = activeRestaurant?.name else { return }
        do {
            shareURL = try ProductionLabelPDFExporter.export(labels: filteredLabels, restaurantName: name)
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProductionLabelShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
