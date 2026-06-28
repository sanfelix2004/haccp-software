import SwiftUI
import SwiftData

struct GoodsReceivingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var records: [GoodsReceipt]
    @Query private var suppliers: [Supplier]
    @Query private var templates: [ProductTemplate]
    @Query private var productImages: [ProductImage]
    @StateObject private var vm = GoodsReceivingViewModel()
    @State private var presentedSheet: GoodsReceivingSheet?
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var showEditSupplier = false
    @State private var newSupplierName = ""
    @State private var showMasterAuthDeleteReceipt = false
    @State private var receiptPendingDeletion: GoodsReceipt?

    private var scopedRecords: [GoodsReceipt] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return records.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    private var scopedSuppliers: [Supplier] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return suppliers.filter { $0.restaurantId == rid }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    private var scopedTemplates: [ProductTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return templates.filter { $0.restaurantId == rid }
    }
    private var filteredTemplates: [ProductTemplate] {
        let byCategory = vm.selectedCategory == .all ? scopedTemplates : scopedTemplates.filter { $0.category == vm.selectedCategory }
        return byCategory.sorted(by: { lhs, rhs in
            let lRecent = vm.recentProductIds.contains(lhs.id)
            let rRecent = vm.recentProductIds.contains(rhs.id)
            if lRecent != rRecent { return lRecent && !rRecent }
            return lhs.name < rhs.name
        })
    }
    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }
    private var permissions: UserPermissions { currentUser.permissions }
    private var canManageSuppliers: Bool { permissions.can(.manageSuppliers) }
    private var canDeleteRecords: Bool { permissions.can(.deleteTraceabilityRecords) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ModuleScreenHeader(
                    title: "Ricezione merci",
                    subtitle: "Registra fornitore e alimento in ingresso. Foto solo in caso di anomalia.",
                    systemImage: "shippingbox.fill",
                    help: ModuleHelpLibrary.sidebar(.goodsReceiving)
                )

                SecondaryButton(title: "Gestisci alimenti in ingresso", icon: "tray.full.fill") {
                    appState.pendingSidebarNavigation = .incomingFoodCatalog
                }

                DashboardCardView(title: "Nuova ricezione", subtitle: "Fornitore e alimento in ingresso", help: ModuleHelpLibrary.sidebar(.goodsReceiving)) {
                    VStack(spacing: 14) {
                        SupplierSelectionView(
                            suppliers: scopedSuppliers,
                            selectedSupplierId: vm.selectedSupplier?.id,
                            canAddSupplier: appState.activeRestaurantId != nil,
                            canEditSupplier: canManageSuppliers,
                            onSelect: { vm.selectedSupplier = $0 },
                            onAdd: {
                                masterAuth.request(permission: .manageSuppliers, permissions: permissions) {
                                    presentedSheet = .addSupplier
                                }
                            },
                            onEdit: {
                                guard canManageSuppliers else { return }
                                guard let selected = vm.selectedSupplier else { return }
                                newSupplierName = selected.name
                                showEditSupplier = true
                            }
                        )
                        ProductCategoryTabsView(selectedCategory: $vm.selectedCategory)
                        if filteredTemplates.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Nessun prodotto template",
                                message: "I template verranno creati automaticamente. Torna tra un attimo o riapri la schermata.",
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
                        HStack(spacing: 10) {
                            Button {
                                masterAuth.request(permission: .manageSuppliers, permissions: permissions) {
                                    presentedSheet = .addSupplier
                                }
                            } label: {
                                Label("Aggiungi fornitore", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .tint(theme.colorPrimary)
                            .disabled(appState.activeRestaurantId == nil)
                            .opacity(appState.activeRestaurantId != nil ? 1 : 0.4)

                            if vm.selectedProduct != nil {
                                Button {
                                    vm.selectedProduct = nil
                                    vm.selectedCategory = .all
                                } label: {
                                    Label("Annulla", systemImage: "xmark")
                                }
                                .buttonStyle(.bordered)
                                .tint(theme.colorTextSecondary)
                            }

                            Spacer()

                            Button {
                                guard vm.selectedSupplier != nil else {
                                    vm.errorMessage = "Seleziona o aggiungi un fornitore."
                                    return
                                }
                                guard vm.selectedProduct != nil else { return }
                                vm.presentIntakeSheet()
                                presentedSheet = .intake
                            } label: {
                                Label("Conferma ricezione", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint((vm.selectedProduct == nil || vm.selectedSupplier == nil) ? theme.colorTextSecondary : theme.colorSuccess)
                            .disabled(vm.selectedProduct == nil || vm.selectedSupplier == nil)
                        }
                    }
                }

                DashboardCardView(title: "Storico ricezioni") {
                    if scopedRecords.isEmpty {
                        DashboardEmptyStateView(state: .init(
                            title: "Nessuna ricezione registrata",
                            message: "Le registrazioni merci con conformità e note appariranno qui.",
                            actionTitle: nil
                        ))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(scopedRecords.prefix(20)) { record in
                                receiptHistoryRow(record)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Ricezione merci")
        .onAppear {
            bootstrapReceivingSession()
        }
        .onChange(of: appState.activeRestaurantId) { _, _ in
            bootstrapReceivingSession()
        }
        .onChange(of: vm.showIntakeSheet) { _, isPresented in
            if isPresented {
                presentedSheet = .intake
            } else if presentedSheet == .intake {
                presentedSheet = nil
            }
        }
        .onChange(of: presentedSheet) { _, sheet in
            vm.showIntakeSheet = sheet == .intake
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .intake:
                if let rid = appState.activeRestaurantId,
                   let user = currentUser,
                   let supplier = vm.selectedSupplier,
                   let product = vm.selectedProduct {
                    RicezioneMerceIntakeSheet(
                        restaurantId: rid,
                        supplier: supplier,
                        product: product,
                        user: user,
                        onSaved: {
                            vm.persistMemory(restaurantId: rid)
                            vm.resetForNext()
                            presentedSheet = nil
                        },
                        onCancel: {
                            vm.showIntakeSheet = false
                            presentedSheet = nil
                        }
                    )
                }
            case .addSupplier:
                NavigationStack {
                    Form {
                        Section {
                            TextField("Nome fornitore", text: $newSupplierName)
                                .textInputAutocapitalization(.words)
                        } footer: {
                            Text("Il fornitore è salvato per questo ristorante e sarà subito selezionabile.")
                        }
                    }
                    .navigationTitle("Nuovo fornitore")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") {
                                newSupplierName = ""
                                presentedSheet = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salva") {
                                addSupplier()
                                presentedSheet = nil
                            }
                            .disabled(newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .alert("Ricezione merci", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Modifica fornitore", isPresented: $showEditSupplier) {
            TextField("Nome fornitore", text: $newSupplierName)
            Button("Annulla", role: .cancel) {}
            Button("Salva") { editSupplier() }
        } message: {
            Text("Aggiorna il nome del fornitore.")
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        .fullScreenCover(isPresented: $showMasterAuthDeleteReceipt) {
            if let master = users.first(where: { $0.role == .master }) {
                MasterAuthOverlay(
                    master: master,
                    operation: .deleteTraceabilityEntry,
                    onAuthorized: {
                        showMasterAuthDeleteReceipt = false
                        if let receipt = receiptPendingDeletion {
                            deleteReceipt(receipt)
                        }
                        receiptPendingDeletion = nil
                    },
                    onCancel: {
                        showMasterAuthDeleteReceipt = false
                        receiptPendingDeletion = nil
                    }
                ) { EmptyView() }
            }
        }
    }

    private enum GoodsReceivingSheet: Identifiable {
        case intake
        case addSupplier

        var id: String {
            switch self {
            case .intake: return "intake"
            case .addSupplier: return "addSupplier"
            }
        }
    }

    private func receiptHistoryRow(_ record: GoodsReceipt) -> some View {
        let ncPhoto = nonCompliancePhoto(for: record)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                if let data = ncPhoto,
                   let thumb = HACCPZoomablePhotoThumbnail(data: data, size: 54, zoomTitle: "Foto anomalia") {
                    thumb
                }
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
                Spacer()
                HACCPBadge(
                    title: record.status.label,
                    style: record.status == .conforme ? .conforme : .nonConforme,
                    showIcon: false
                )
            }

            if record.status != .conforme {
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

            if canDeleteRecords {
                HStack {
                    Spacer()
                    Button("Elimina", role: .destructive) {
                        receiptPendingDeletion = record
                        showMasterAuthDeleteReceipt = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(ThemeManager.shared.colorSurface)
        .cornerRadius(10)
    }

    private func nonCompliancePhoto(for record: GoodsReceipt) -> Data? {
        if let data = record.photoData, !data.isEmpty { return data }
        let images = productImages.filter { $0.receivedItemId == record.id && $0.type == .nonComplianceRequired }
        return images.sorted { $0.createdAt > $1.createdAt }.first?.imageData
    }

    private func bootstrapReceivingSession() {
        guard let rid = appState.activeRestaurantId else { return }
        ProductTemplateSeeder.ensureTemplates(restaurantId: rid, modelContext: modelContext)
        vm.loadMemory(restaurantId: rid)
        vm.selectedSupplier = scopedSuppliers.first(where: { $0.id == vm.lastSupplierId }) ?? scopedSuppliers.first
    }

    private func addSupplier() {
        guard let rid = appState.activeRestaurantId else { return }
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let supplier = Supplier(restaurantId: rid, name: name)
        modelContext.insert(supplier)
        try? modelContext.save()
        vm.selectedSupplier = supplier
        vm.persistMemory(restaurantId: rid)
        newSupplierName = ""
    }

    private func editSupplier() {
        guard canManageSuppliers else { return }
        guard let selected = vm.selectedSupplier else { return }
        let name = newSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selected.name = name
        try? modelContext.save()
        newSupplierName = ""
    }

    private func deleteReceipt(_ receipt: GoodsReceipt) {
        productImages
            .filter { $0.receivedItemId == receipt.id }
            .forEach { modelContext.delete($0) }
        modelContext.delete(receipt)
        try? modelContext.save()
    }
}
