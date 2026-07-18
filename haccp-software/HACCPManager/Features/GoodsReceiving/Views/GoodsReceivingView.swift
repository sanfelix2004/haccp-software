import SwiftUI
import SwiftData

// MARK: - GoodsReceivingView
// Vista principale per il modulo Ricezione Merci.
//
// Architettura:
//   - GoodsReceivingViewModel  → stato UI volatile (selezioni, messaggi di errore)
//   - GoodsReceivingDataStore  → sorgente di verità per i dati dal database
//   - GoodsReceivingService    → logica di business (validazione + salvataggio)
//
// Gestione gesture:
//   - Lo storico usa una `List` nativa con `.swipeActions` per eliminare senza conflitti
//     con lo `ScrollView` verticale esterno (scrollDisabled sulla List interna).
//
// Gestione stato sheet:
//   - Un singolo enum `GoodsReceivingSheet?` come source of truth per tutti i modali.
//     Eliminato il flag booleano `showIntakeSheet` sul ViewModel che causava conflitti.

struct GoodsReceivingView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject private var appState: AppState
    @Query private var users: [LocalUser]

    // MARK: - State

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.goodsReceiving
    @StateObject private var vm = GoodsReceivingViewModel()

    /// Unica sorgente di verità per i modali: nil = nessun modale aperto.
    @State private var presentedSheet: GoodsReceivingSheet?

    // Modifica fornitore
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var showEditSupplier = false
    @State private var pendingSupplierName = ""

    // Eliminazione ricevuta — flusso a 2 step: confirmationDialog → MasterAuth
    @State private var receiptPendingDeletion: GoodsReceipt?
    @State private var showDeleteConfirmation  = false
    @State private var showMasterAuthForDelete = false

    // MARK: - Derived Data
    // Computed properties filtrate per il ristorante attivo.
    // NOTA: non usare `[weak self]` in computed property — non è necessario
    // perché SwiftUI gestisce il ciclo di vita della View.

    private var restaurantId: UUID? { appState.activeRestaurantId }

    private var scopedRecords: [GoodsReceipt] {
        guard let rid = restaurantId else { return [] }
        return dataStore.records
            .filter { $0.restaurantId == rid }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var scopedSuppliers: [Supplier] {
        guard let rid = restaurantId else { return [] }
        return dataStore.suppliers
            .filter { $0.restaurantId == rid }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var scopedTemplates: [ProductTemplate] {
        guard let rid = restaurantId else { return [] }
        return dataStore.templates.filter { $0.restaurantId == rid }
    }

    private var filteredTemplates: [ProductTemplate] {
        let base = vm.selectedCategory == .all
            ? scopedTemplates
            : scopedTemplates.filter { $0.category == vm.selectedCategory }
        return base.sorted { lhs, rhs in
            let lRecent = vm.recentProductIds.contains(lhs.id)
            let rRecent = vm.recentProductIds.contains(rhs.id)
            if lRecent != rRecent { return lRecent }
            return lhs.name < rhs.name
        }
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canManageSuppliers: Bool { permissions.can(.manageSuppliers) }
    private var canDeleteRecords: Bool    { permissions.can(.deleteTraceabilityRecords) }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                catalogButton
                newReceiptCard
                historyCard
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Ricezione merci")
        .moduleScreenLoad(restaurantId: restaurantId) {
            guard let rid = restaurantId else { return }
            dataStore.reload(context: modelContext, restaurantId: rid)
            bootstrapReceivingSession(restaurantId: rid)
        }
        // MARK: Sheet Presentation
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        // MARK: Alerts & Modals
        .alert(
            "Ricezione merci",
            isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Modifica fornitore", isPresented: $showEditSupplier) {
            TextField("Nome fornitore", text: $pendingSupplierName)
            Button("Annulla", role: .cancel) { pendingSupplierName = "" }
            Button("Salva") { commitEditSupplier() }
        } message: {
            Text("Aggiorna il nome del fornitore.")
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first { $0.role == .master })
        // MARK: Delete Flow
        // Step 1: confirmation dialog di sistema (tasto fisico difficile da premere per sbaglio).
        .confirmationDialog(
            "Eliminare questa ricezione?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) { showMasterAuthForDelete = true }
            Button("Annulla", role: .cancel)     { receiptPendingDeletion = nil }
        } message: {
            if let r = receiptPendingDeletion {
                Text("\(r.productNameSnapshot) — \(r.receivedAt.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        // Step 2: MasterAuth overlay (sicurezza operativa HACCP).
        .fullScreenCover(isPresented: $showMasterAuthForDelete) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .deleteTraceabilityEntry,
                    onAuthorized: {
                        showMasterAuthForDelete = false
                        if let receipt = receiptPendingDeletion {
                            commitDeleteReceipt(receipt)
                        }
                        receiptPendingDeletion = nil
                    },
                    onCancel: {
                        showMasterAuthForDelete = false
                        receiptPendingDeletion = nil
                    }
                ) { EmptyView() }
            }
        }
        // MARK: Reactive reload fornitori
        // Quando la lista fornitori si aggiorna (es. dopo force reload asincrono),
        // riseleziona il fornitore corrente se ancora presente nella lista aggiornata.
        .onChange(of: dataStore.suppliers) { _, updated in
            guard let rid = restaurantId else { return }
            let scoped = updated.filter { $0.restaurantId == rid }
            if let current = vm.selectedSupplier,
               scoped.contains(where: { $0.id == current.id }) == false,
               let match = scoped.first(where: { $0.id == current.id }) {
                vm.selectedSupplier = match
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        ModuleScreenHeader(
            title: "Ricezione merci",
            subtitle: "Registra fornitore e alimento in ingresso. Foto solo in caso di anomalia.",
            systemImage: "shippingbox.fill",
            help: ModuleHelpLibrary.sidebar(.goodsReceiving)
        )
    }

    private var catalogButton: some View {
        SecondaryButton(title: "Gestisci alimenti in ingresso", icon: "tray.full.fill") {
            appState.pendingSidebarNavigation = .incomingFoodCatalog
        }
    }

    private var newReceiptCard: some View {
        DashboardCardView(
            title: "Nuova ricezione",
            subtitle: "Fornitore e alimento in ingresso",
            help: ModuleHelpLibrary.sidebar(.goodsReceiving)
        ) {
            VStack(spacing: 14) {
                supplierSection
                ProductCategoryTabsView(selectedCategory: $vm.selectedCategory)
                productSection
                receiptActions
            }
        }
    }

    private var supplierSection: some View {
        SupplierSelectionView(
            suppliers: scopedSuppliers,
            selectedSupplierId: vm.selectedSupplier?.id,
            canAddSupplier: restaurantId != nil,
            canEditSupplier: canManageSuppliers,
            onSelect: { vm.selectedSupplier = $0 },
            onAdd: {
                masterAuth.request(permission: .manageSuppliers, permissions: permissions) {
                    pendingSupplierName = ""
                    presentedSheet = .addSupplier
                }
            },
            onEdit: {
                guard canManageSuppliers, let s = vm.selectedSupplier else { return }
                pendingSupplierName = s.name
                showEditSupplier = true
            }
        )
    }

    @ViewBuilder
    private var productSection: some View {
        if filteredTemplates.isEmpty {
            DashboardEmptyStateView(state: .init(
                title: "Nessun prodotto template",
                message: "I template verranno creati automaticamente. Riapri la schermata tra un attimo.",
                actionTitle: nil
            ))
        } else {
            ProductSelectionGridView(
                products: filteredTemplates,
                recentProductIds: vm.recentProductIds,
                selectedProductId: vm.selectedProduct?.id,
                groupsByCategory: vm.selectedCategory == .all,
                onSelect: { vm.selectProductTemplate($0) }
            )
        }
    }

    private var receiptActions: some View {
        HStack(spacing: 10) {
            // Aggiungi fornitore rapido (duplicato del bottone in SupplierSelectionView,
            // utile per utenti che non scrollano nella griglia fornitori).
            Button {
                masterAuth.request(permission: .manageSuppliers, permissions: permissions) {
                    pendingSupplierName = ""
                    presentedSheet = .addSupplier
                }
            } label: {
                Label("Aggiungi fornitore", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .tint(theme.colorPrimary)
            .disabled(restaurantId == nil)
            .opacity(restaurantId != nil ? 1 : 0.4)

            // Deseleziona prodotto corrente.
            if vm.selectedProduct != nil {
                Button {
                    withAnimation { vm.selectedProduct = nil; vm.selectedCategory = .all }
                } label: {
                    Label("Annulla", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(theme.colorTextSecondary)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer()

            // CTA principale — disabilitato finché fornitore E prodotto non sono selezionati.
            Button {
                guard vm.selectedSupplier != nil else {
                    vm.errorMessage = "Seleziona o aggiungi un fornitore."
                    return
                }
                guard vm.selectedProduct != nil else { return }
                presentedSheet = .intake
            } label: {
                Label("Conferma ricezione", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.canConfirmIntake ? theme.colorSuccess : theme.colorTextSecondary)
            .disabled(!vm.canConfirmIntake)
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedProduct != nil)
    }

    private var historyCard: some View {
        DashboardCardView(title: "Storico ricezioni") {
            if scopedRecords.isEmpty {
                DashboardEmptyStateView(state: .init(
                    title: "Nessuna ricezione registrata",
                    message: "Le registrazioni merci con conformità e note appariranno qui.",
                    actionTitle: nil
                ))
            } else {
                // BUG FIX: `List` nativa con `.swipeActions` elimina il conflitto
                // scroll verticale / swipe orizzontale presente nella vecchia implementazione
                // con `ForEach in VStack`. La `List` interna è scrollDisabled per delegare
                // lo scroll alla `ScrollView` esterna e dimensionarsi correttamente.
                List {
                    ForEach(scopedRecords.prefix(20)) { record in
                        ReceiptHistoryRow(
                            record: record,
                            nonCompliancePhoto: nonCompliancePhoto(for: record)
                        )
                        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDeleteRecords {
                                Button(role: .destructive) {
                                    receiptPendingDeletion = record
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: CGFloat(min(scopedRecords.prefix(20).count, 20)) * 108)
            }
        }
    }

    // MARK: - Sheet Router

    @ViewBuilder
    private func sheetContent(for sheet: GoodsReceivingSheet) -> some View {
        switch sheet {
        case .intake:
            intakeSheet
        case .addSupplier:
            addSupplierSheet
        }
    }

    @ViewBuilder
    private var intakeSheet: some View {
        if let rid = restaurantId,
           let user = currentUser,
           let supplier = vm.selectedSupplier,
           let product = vm.selectedProduct {
            RicezioneMerceIntakeSheet(
                restaurantId: rid,
                supplier: supplier,
                product: product,
                user: user,
                onSaved: {
                    guard let rid = restaurantId else { return }
                    vm.persistMemory(restaurantId: rid)
                    vm.resetForNext()
                    presentedSheet = nil
                    // Ricarica per mostrare la nuova ricevuta nel log storico.
                    dataStore.forceReload(context: modelContext, restaurantId: rid)
                },
                onCancel: { presentedSheet = nil }
            )
        }
    }

    private var addSupplierSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome fornitore", text: $pendingSupplierName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { commitAddSupplier() }
                } footer: {
                    Text("Il fornitore è salvato per questo ristorante e sarà subito selezionabile.")
                }
            }
            .navigationTitle("Nuovo fornitore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        pendingSupplierName = ""
                        presentedSheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        commitAddSupplier()
                        presentedSheet = nil
                    }
                    .disabled(pendingSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Business Actions

    private func bootstrapReceivingSession(restaurantId rid: UUID) {
        RestaurantModuleBootstrap.shared.runOnce(restaurantId: rid, module: "goods-templates") {
            ProductTemplateSeeder.ensureTemplates(restaurantId: rid, modelContext: modelContext)
        }
        vm.loadMemory(restaurantId: rid)
        // Riseleziona il fornitore dell'ultima sessione se ancora presente nel DataStore.
        vm.selectedSupplier = scopedSuppliers.first { $0.id == vm.lastSupplierId } ?? scopedSuppliers.first
    }

    /// Salva il nuovo fornitore con optimistic update + force reload asincrono.
    private func commitAddSupplier() {
        guard let rid = restaurantId else { return }
        let name = pendingSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let supplier = Supplier(restaurantId: rid, name: name)
        modelContext.insert(supplier)
        try? modelContext.save()

        // 1. Optimistic update: l'utente vede il nuovo fornitore immediatamente.
        dataStore.appendSupplier(supplier)
        // 2. Selezione automatica del fornitore appena creato.
        vm.selectedSupplier = supplier
        vm.persistMemory(restaurantId: rid)
        pendingSupplierName = ""

        // 3. Force reload asincrono come garanzia di coerenza con il DB.
        Task { @MainActor in
            await Task.yield()
            dataStore.forceReload(context: modelContext, restaurantId: rid)
        }
    }

    /// Salva la modifica del nome del fornitore selezionato.
    private func commitEditSupplier() {
        guard canManageSuppliers else { return }
        guard let selected = vm.selectedSupplier else { return }
        let name = pendingSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selected.name = name
        try? modelContext.save()
        pendingSupplierName = ""
    }

    /// Elimina la ricevuta e le foto associate, poi aggiorna il log storico.
    private func commitDeleteReceipt(_ receipt: GoodsReceipt) {
        // Elimina prima le immagini associate (integrità referenziale).
        dataStore.productImages
            .filter { $0.receivedItemId == receipt.id }
            .forEach { modelContext.delete($0) }
        modelContext.delete(receipt)
        try? modelContext.save()
        // Ricarica per riflettere l'eliminazione nello storico.
        guard let rid = restaurantId else { return }
        dataStore.forceReload(context: modelContext, restaurantId: rid)
    }

    /// Recupera la foto di non conformità per una ricevuta (prima dal campo inline, poi dalla tabella ProductImage).
    private func nonCompliancePhoto(for record: GoodsReceipt) -> Data? {
        if let data = record.photoData, !data.isEmpty { return data }
        return dataStore.productImages
            .filter { $0.receivedItemId == record.id && $0.type == .nonComplianceRequired }
            .sorted { $0.createdAt > $1.createdAt }
            .first?.imageData
    }

    // MARK: - Sheet Enum

    private enum GoodsReceivingSheet: String, Identifiable {
        case intake
        case addSupplier
        var id: String { rawValue }
    }
}

// MARK: - ReceiptHistoryRow
// Estratto in componente separato per:
// 1. Ridurre la complessità del body principale.
// 2. Consentire re-render selettivo (SwiftUI lo identifica come View separata).
// 3. Rendere il componente riusabile in altri contesti (es. export, ricerca).

private struct ReceiptHistoryRow: View {
    let record: GoodsReceipt
    let nonCompliancePhoto: Data?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                photoThumbnail
                recordInfo
                Spacer()
                statusBadge
            }
            nonComplianceDetails
        }
        .padding(12)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var photoThumbnail: some View {
        if let data = nonCompliancePhoto,
           let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 54, zoomTitle: "Foto anomalia") {
            thumb
        }
    }

    private var recordInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.productNameSnapshot)
                .font(.headline)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            Text(record.supplierNameSnapshot)
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            Text(record.receivedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.colorTextSecondary)
        }
    }

    private var statusBadge: some View {
        HACCPBadge(
            title: record.status.label,
            style: record.status == .conforme ? .conforme : .nonConforme,
            showIcon: false
        )
    }

    @ViewBuilder
    private var nonComplianceDetails: some View {
        if record.status != .conforme {
            VStack(alignment: .leading, spacing: 2) {
                if let notes = record.notes, !notes.isEmpty {
                    Text("Problema: \(notes)")
                        .font(.caption)
                        .foregroundStyle(theme.colorWarning)
                }
                if let action = record.correctiveAction, !action.isEmpty {
                    Text("Azione: \(action)")
                        .font(.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
        }
    }
}
