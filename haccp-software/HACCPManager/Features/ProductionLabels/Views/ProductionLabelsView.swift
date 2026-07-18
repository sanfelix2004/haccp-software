//
//  ProductionLabelsView.swift
//  Hub etichette HACCP — una card per modulo collegato.
//

import SwiftUI
import SwiftData

struct ProductionLabelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.productionLabels

    @State private var selectedLabelId: UUID?
    @State private var pendingWorkspaceSource: ProductionLabelLinkedSource?
    @ObservedObject private var printQueue = ProductionLabelPrintQueue.shared
    @ObservedObject private var printerManager = ClabelPrinterManager.shared
    @State private var showScanner = false
    @State private var scannedLabelData: ProductionLabelScanData?
    @State private var errorMessage: String?
    @State private var masterAuth = MasterAuthCoordinator()

    private let vm = ProductionLabelsViewModel()

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var permissions: UserPermissions { currentUser.permissions }

    private var activeRestaurant: Restaurant? {
        guard let rid = appState.activeRestaurantId else { return nil }
        return restaurants.first { $0.id == rid }
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
        .toolbar {
            if appState.activeRestaurantId != nil, ProductionLabelScannerSupport.isAvailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        masterAuth.request(permission: .executeRecords, permissions: permissions) {
                            showScanner = true
                        }
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("Scansiona QR etichetta")
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            ProductionLabelScannerSheet { payload in
                handleScannedPayload(payload)
            }
        }
        .sheet(item: $scannedLabelData) { data in
            ProductionLabelScannedDetailView(
                data: data,
                showsOfflineBanner: !dataStore.labels.contains(where: { $0.id == data.id }),
                onOpenInArchive: dataStore.labels.contains(where: { $0.id == data.id })
                    ? {
                        scannedLabelData = nil
                        selectedLabelId = data.id
                    }
                    : nil
            )
        }
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            reloadData()
        }
        .onChange(of: printQueue.pendingJobs.count) { _, _ in
            Task { await drainPrintQueue() }
        }
        .onChange(of: printerManager.isReadyToPrint) { _, ready in
            if ready {
                Task { await drainPrintQueue() }
            }
        }
        .navigationDestination(item: $selectedLabelId) { labelId in
            if let user = currentUser {
                ProductionLabelDetailLoaderView(
                    labelId: labelId,
                    restaurantId: appState.activeRestaurantId,
                    restaurantName: activeRestaurant?.name ?? "Ristorante",
                    user: user,
                    onChanged: { reloadData() }
                )
            }
        }
        .navigationDestination(item: $pendingWorkspaceSource) { source in
            if let rid = appState.activeRestaurantId, let user = currentUser {
                ProductionLabelSourceWorkspaceView(
                    source: source,
                    dataStore: dataStore,
                    restaurantId: rid,
                    restaurantName: activeRestaurant?.name ?? "Ristorante",
                    user: user,
                    onChanged: { reloadData() }
                )
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
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
    }

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.sectionSpacing) {
                ModuleScreenHeader(
                    title: "Etichette di produzione",
                    subtitle: "Etichette per piatti preparati, abbattimenti e decongelamenti",
                    systemImage: "tag.fill",
                    help: ModuleHelpLibrary.sidebar(.productionLabels)
                )

                statsRow

                if !printQueue.pendingJobs.isEmpty {
                    printQueueCard
                }

                if ProductionLabelScannerSupport.isAvailable {
                    DashboardCardView(title: "Scansione", subtitle: "Solo da iPad — leggi un QR già stampato") {
                        SecondaryButton(title: "Scansiona QR etichetta", icon: "qrcode.viewfinder") {
                            masterAuth.request(permission: .executeRecords, permissions: permissions) {
                                showScanner = true
                            }
                        }
                    }
                }

                DashboardCardView(title: "Tipi di etichetta", subtitle: "Tocca un modulo per creare e stampare") {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 14
                    ) {
                        ForEach(ProductionLabelLinkedSource.allCases) { source in
                            Button {
                                masterAuth.request(permission: .executeRecords, permissions: permissions) {
                                    pendingWorkspaceSource = source
                                }
                            } label: {
                                sourceCard(source)
                            }
                            .buttonStyle(PremiumPressButtonStyle())
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding + 8)
        }
    }

    private func sourceCard(_ source: ProductionLabelLinkedSource) -> some View {
        let labeled = vm.labelCount(from: dataStore.labels, source: source)
        let pending = vm.pendingSourceCount(for: source, dataStore: dataStore, labels: dataStore.labels)

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colorPrimary, theme.colorPrimary.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(theme.colorPrimary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: source.icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.colorPrimary)
                    }
                    Spacer(minLength: 8)
                    statusBadge(pending: pending, labeled: labeled)
                }

                Text(source.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                    .multilineTextAlignment(.leading)

                Text(source.subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: theme.shadows.card.color.opacity(0.35), radius: 6, y: 2)
    }

    @ViewBuilder
    private func statusBadge(pending: Int, labeled: Int) -> some View {
        if pending > 0 {
            Text("\(pending) da fare")
                .font(theme.typography.caption2.weight(.bold))
                .foregroundStyle(theme.colorTextOnPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.colorPrimary)
                .clipShape(Capsule())
        } else if labeled > 0 {
            Label("\(labeled)", systemImage: "checkmark.seal.fill")
                .font(theme.typography.caption2.weight(.semibold))
                .foregroundStyle(theme.colorSuccess)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.colorSuccess.opacity(0.12))
                .clipShape(Capsule())
        } else {
            Text("Vuoto")
                .font(theme.typography.caption2.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.colorDivider.opacity(0.5))
                .clipShape(Capsule())
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

    private var printQueueCard: some View {
        DashboardCardView(
            title: "Coda stampa",
            subtitle: printerManager.isConnected ? "Invio alla stampante CLABEL" : "Stampante non connessa"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(printQueue.pendingJobs) { job in
                    HStack {
                        Image(systemName: "printer")
                            .foregroundStyle(theme.colorInfo)
                        Text("Etichetta in attesa · \(job.copies) copie")
                            .font(theme.typography.subheadline)
                        Spacer()
                        if printQueue.isProcessing {
                            ProgressView()
                        }
                    }
                }
                if !printerManager.isConnected {
                    Text("Collega la stampante da Impostazioni → Stampanti.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorWarning)
                }
            }
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
            includeArchived: true
        )
    }

    private func drainPrintQueue() async {
        await printQueue.processPending(
            labels: dataStore.labels,
            modelContext: modelContext,
            restaurantName: activeRestaurant?.name
        )
    }

    private func handleScannedPayload(_ payload: String) {
        guard let scanned = ProductionLabelQRService.parseScanned(payload) else {
            errorMessage = "QR non riconosciuto. Usa un’etichetta HACCP Manager."
            return
        }

        do {
            if let label = try ProductionLabelLookupService.fetchLabel(
                id: scanned.id,
                restaurantId: appState.activeRestaurantId,
                context: modelContext
            ) {
                if !dataStore.labels.contains(where: { $0.id == label.id }) {
                    dataStore.mergeFetchedLabel(label)
                }
                scannedLabelData = ProductionLabelScanData.from(
                    label,
                    restaurantName: activeRestaurant?.name
                )
                return
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if scanned.hasRichContent {
            scannedLabelData = scanned
            return
        }

        errorMessage = """
        QR illeggibile o etichetta vecchia. Ristampa l’etichetta (formato 40×30 compatto) e riprova tenendo il QR ben inquadrato.
        """
    }
}
