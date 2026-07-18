import SwiftUI
import SwiftData

struct ProductionSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var categories: [ProductionCategory]
    @Query private var productions: [Production]
    @Query private var links: [TraceabilityLink]
    @Query private var blastRecords: [BlastChillingRecord]
    @Environment(\.theme) private var theme
    @StateObject private var vm = ProductionSelectionViewModel()
    @StateObject private var camera = FinalizeReceiptCameraViewModel()
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var showMasterAuthForDelete = false
    @State private var productionPendingDeletion: Production?
    @State private var productionPhotoData: Data?
    @State private var showCamera = false
    private let service = ProductionLibraryService()
    let initialSelectedIds: Set<UUID>

    let onCancel: () -> Void
    let onConfirm: ([Production], Data?) -> Void

    private var scopedCategories: [ProductionCategory] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return categories.filter { $0.restaurantId == rid }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var scopedProductions: [Production] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return productions.filter { $0.restaurantId == rid }
    }

    private var filteredProductions: [Production] {
        if let selectedCategoryId = vm.selectedCategoryId {
            return scopedProductions
                .filter { $0.categoryId == selectedCategoryId }
                .sorted(by: productionNameSort)
        }
        return scopedProductions.sorted(by: productionCategorySort)
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
    }

    private var permissions: UserPermissions { currentUser.permissions }
    private var canManageProductions: Bool { permissions.can(.manageProductionLibrary) }
    private var canExecute: Bool { permissions.can(.executeRecords) }

    private var categoryOrderById: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: scopedCategories.map { ($0.id, $0.orderIndex) })
    }

    private var selectedSingleProduction: Production? {
        guard vm.selectedProductionIds.count == 1,
              let id = vm.selectedProductionIds.first else { return nil }
        return scopedProductions.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(nil, title: "Tutti")
                        ForEach(scopedCategories) { category in
                            categoryButton(category.id, title: category.name)
                        }
                    }
                }

                productionDishPhotoSection

                ScrollView {
                    ProductionGrid(
                        productions: filteredProductions,
                        selectedProductionIds: vm.selectedProductionIds,
                        isEditMode: vm.isEditMode,
                        showsShelfLife: true,
                        onSelect: { production in
                            if vm.selectedProductionIds.contains(production.id) {
                                vm.selectedProductionIds.remove(production.id)
                            } else {
                                vm.selectedProductionIds.insert(production.id)
                            }
                        },
                        onDelete: deleteProduction
                    )
                    .padding(.bottom, 10)
                }

                HStack(spacing: 10) {
                    Button("+ Aggiungere") {
                        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
                            vm.newProductionCategoryId = vm.selectedCategoryId ?? scopedCategories.first?.id
                            vm.showAddSheet = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(ThemeManager.shared.colorPrimary)
                    Button("Modifica") {
                        guard let selected = selectedSingleProduction else {
                            vm.errorMessage = "Seleziona una sola produzione da modificare."
                            return
                        }
                        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
                            vm.productionToEdit = selected
                            vm.newProductionName = selected.name
                            vm.newProductionCategoryId = selected.categoryId
                            vm.showEditSheet = true
                        }
                    }
                        .buttonStyle(.bordered)
                        .tint(ThemeManager.shared.colorPrimary)
                        .disabled(selectedSingleProduction == nil)
                    Button("Elimina", role: .destructive) {
                        guard let selected = selectedSingleProduction else {
                            vm.errorMessage = "Seleziona una sola produzione da eliminare."
                            return
                        }
                        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
                            performDeleteProduction(selected)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedSingleProduction == nil)
                    Spacer()
                    Button("Annullare", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(ThemeManager.shared.colorPrimary)
                    Button("Ho finito") {
                        let selected = scopedProductions.filter { vm.selectedProductionIds.contains($0.id) }
                        onConfirm(selected, productionPhotoData)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.selectedProductionIds.isEmpty ? .gray : .green)
                    .disabled(vm.selectedProductionIds.isEmpty)
                }
            }
            .padding(20)
            .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
            .navigationTitle("Produzioni")
            .onAppear {
                vm.selectedProductionIds = initialSelectedIds
                guard let rid = appState.activeRestaurantId else { return }
                service.ensureDefaults(
                    restaurantId: rid,
                    modelContext: modelContext
                )
            }
            .sheet(isPresented: $vm.showAddSheet) {
                productionEditor(title: "Nuova produzione", production: nil)
            }
            .sheet(isPresented: $vm.showEditSheet) {
                if let production = vm.productionToEdit {
                    productionEditor(title: "Modifica produzione", production: production)
                }
            }
            .fullScreenCover(isPresented: $showMasterAuthForDelete) {
                masterOverlay {
                    showMasterAuthForDelete = false
                    if let production = productionPendingDeletion {
                        performDeleteProduction(production)
                    }
                    productionPendingDeletion = nil
                } onCancel: {
                    showMasterAuthForDelete = false
                    productionPendingDeletion = nil
                }
            }
            .alert("Produzioni", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showCamera) {
                productionCameraSheet
            }
            .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
        }
    }

    private var productionDishPhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foto piatto finito (opzionale)")
                .font(theme.typography.subheadline.weight(.semibold))
            Text("Non usa la foto dell’alimento in ingresso: scatta solo se vuoi documentare il piatto.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
            if let productionPhotoData,
               let thumb = HACCPZoomablePhotoThumbnail(
                data: productionPhotoData,
                size: 80,
                zoomTitle: "Piatto finito"
               ) {
                HStack(spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Scatta di nuovo") { showCamera = true }
                            .font(theme.typography.caption.weight(.semibold))
                        Button("Rimuovi") { self.productionPhotoData = nil }
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorError)
                    }
                }
            } else {
                Button {
                    showCamera = true
                } label: {
                    Label("Scatta foto del piatto", systemImage: "camera.fill")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var productionCameraSheet: some View {
        NavigationStack {
            ZStack {
                FinalizeCameraSessionPreview(session: camera.session, cameraViewModel: camera)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    Button("Scatta") { camera.capturePhoto() }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 28)
                }
            }
            .navigationTitle("Foto piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showCamera = false }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
            .onReceive(camera.$capturedPhotoData) { data in
                guard let data, !data.isEmpty else { return }
                camera.resetCaptureBuffer()
                showCamera = false
                productionPhotoData = data
            }
        }
    }

    @ViewBuilder
    private func productionEditor(title: String, production: Production?) -> some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Nome produzione", text: $vm.newProductionName)
                    Picker("Categoria", selection: Binding(
                        get: { vm.newProductionCategoryId ?? scopedCategories.first?.id ?? UUID() },
                        set: { vm.newProductionCategoryId = $0 }
                    )) {
                        ForEach(scopedCategories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }
                if production != nil {
                    Section {
                        Text("La produzione resta condivisa tra Abbattimento e Tracciabilità.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullare") {
                        vm.showAddSheet = false
                        vm.showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveProduction(production) }
                        .disabled(vm.newProductionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func categoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            vm.selectedCategoryId = id
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(vm.selectedCategoryId == id ? ThemeManager.shared.colorTextOnPrimary : ThemeManager.shared.colorTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(vm.selectedCategoryId == id ? ThemeManager.shared.colorPrimary : ThemeManager.shared.colorDivider)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func productionNameSort(_ lhs: Production, _ rhs: Production) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func productionCategorySort(_ lhs: Production, _ rhs: Production) -> Bool {
        let lhsOrder = categoryOrderById[lhs.categoryId] ?? Int.max
        let rhsOrder = categoryOrderById[rhs.categoryId] ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        return productionNameSort(lhs, rhs)
    }

    private func saveProduction(_ production: Production?) {
        guard
            let rid = appState.activeRestaurantId,
            let categoryId = vm.newProductionCategoryId,
            let category = scopedCategories.first(where: { $0.id == categoryId })
        else { return }

        do {
            if let production {
                guard permissions.canPerform(.manageProductionLibrary) else {
                    vm.errorMessage = "Serve l'autorizzazione MASTER."
                    return
                }
                try service.updateProduction(
                    production,
                    name: vm.newProductionName,
                    category: category,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
            } else {
                guard permissions.canPerform(.manageProductionLibrary) else {
                    vm.errorMessage = "Serve l'autorizzazione MASTER."
                    return
                }
                try service.addProduction(
                    name: vm.newProductionName,
                    category: category,
                    restaurantId: rid,
                    existingProductions: scopedProductions,
                    modelContext: modelContext
                )
            }
            vm.newProductionName = ""
            vm.showAddSheet = false
            vm.showEditSheet = false
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func masterOverlay(onAuthorized: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        if let master = users.first(where: { $0.role == .master }) {
            MasterAuthOverlay(
                master: master,
                operation: .privilegedAction,
                onAuthorized: onAuthorized,
                onCancel: onCancel
            ) {
                EmptyView()
            }
        }
    }

    private func deleteProduction(_ production: Production) {
        guard canManageProductions else {
            productionPendingDeletion = production
            showMasterAuthForDelete = true
            return
        }
        performDeleteProduction(production)
    }

    private func performDeleteProduction(_ production: Production) {
        do {
            try service.deleteProductionIfUnused(
                production,
                traceabilityLinks: links,
                blastRecords: blastRecords,
                modelContext: modelContext
            )
            vm.selectedProductionIds.remove(production.id)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
    }
}
