import SwiftUI
import SwiftData

/// Gestione centralizzata del catalogo piatti (Alici, Baccalà, …) usato da
/// Abbattimento, Decongelamento e Tracciabilità.
struct ProductionCatalogManagementView: View {
    /// Se `true`, nasconde l'header schermata (es. dentro Impostazioni).
    var embeddedInSettings: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var session: RestaurantSessionContext

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.productionCatalog

    @State private var selectedCategoryId: UUID?
    @State private var selectedProduction: Production?
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var productionToEdit: Production?
    @State private var newProductionName = ""
    @State private var newProductionCategoryId: UUID?
    @State private var shelfLifeDays = 3
    @State private var errorMessage: String?
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var presentation = ProductionCatalogPresentation.empty

    private let service = BlastChillingService()

    private var scopedCategories: [ProductionCategory] {
        dataStore.categories
    }

    private var scopedProductions: [Production] {
        dataStore.productions
    }

    private var visibleProductions: [Production] {
        presentation.flatProductions
    }

    private var currentUser: LocalUser? {
        session.currentUser
    }

    private var permissions: UserPermissions { currentUser.permissions }

    var body: some View {
        Group {
            if appState.activeRestaurantId == nil {
                DashboardEmptyStateView(state: .init(
                    title: "Seleziona un ristorante",
                    message: "Il catalogo piatti è legato al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(theme.spacing.screenPadding)
            } else if dataStore.isLoading && scopedProductions.isEmpty && scopedCategories.isEmpty {
                ProgressView("Caricamento catalogo…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                catalogScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(embeddedInSettings ? "" : "Catalogo piatti")
        .haccpControlTint()
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            dataStore.reload(context: modelContext, restaurantId: rid)
        }
        .onChange(of: dataStore.dataRevision) { _, _ in
            rebuildPresentation()
        }
        .onChange(of: selectedCategoryId) { _, _ in
            rebuildPresentation()
        }
        .onAppear {
            rebuildPresentation()
        }
        .sheet(isPresented: $showAddSheet) {
            productionEditor(title: "Nuovo piatto", production: nil)
        }
        .sheet(isPresented: $showEditSheet) {
            if let production = productionToEdit {
                productionEditor(title: "Modifica piatto", production: production)
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: session.masterUser)
        .alert("Catalogo piatti", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var catalogScroll: some View {
        ScrollView {
            VStack(spacing: theme.spacing.sectionSpacing) {
                if !embeddedInSettings {
                    ModuleScreenHeader(
                        title: "Catalogo piatti",
                        subtitle: "Menu per Abbattimento e Tracciabilità · durata indicativa in frigo su ogni piatto",
                        systemImage: "fork.knife",
                        help: ModuleHelpLibrary.sidebar(.productionCatalog)
                    )
                }

                DashboardCardView(
                    title: "Gestione piatti",
                    subtitle: "Aggiungi, modifica o elimina le voci del menu · PIN MASTER per l'operatore"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        actionBar
                        categoryTabs

                        if let selected = selectedProduction {
                            selectedBanner(selected)
                        }

                        Text("\(visibleProductions.count) piatti")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)

                        if visibleProductions.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Catalogo vuoto",
                                message: "Aggiungi il primo piatto per questa categoria.",
                                actionTitle: "Aggiungi piatto"
                            )) {
                                requestAdd()
                            }
                        } else {
                            ProductionSelectionGridView(
                                layout: presentation,
                                selectedProductionId: selectedProduction?.id,
                                onSelect: { selectedProduction = $0 }
                            )
                        }
                    }
                }
            }
            .padding(theme.spacing.screenPadding)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            PrimaryButton(title: "Aggiungi piatto", icon: "plus.circle.fill") {
                requestAdd()
            }
            if let selected = selectedProduction {
                SecondaryButton(title: "Modifica", icon: "pencil") {
                    requestEdit(selected)
                }
                Button(role: .destructive) {
                    requestDelete(selected)
                } label: {
                    Label("Elimina", systemImage: "trash")
                        .font(theme.typography.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
    }

    private func selectedBanner(_ production: Production) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.colorSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("Selezionato: \(production.name)")
                    .font(theme.typography.subheadline.bold())
                    .foregroundStyle(theme.colorTextPrimary)
                Text(production.categoryNameSnapshot)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Text("Durata indicativa: \(production.catalogShelfLifeLabel)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
            Button("Deseleziona") { selectedProduction = nil }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)
        }
        .padding(12)
        .background(theme.colorPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryButton(nil, title: "Tutti")
                ForEach(scopedCategories) { category in
                    categoryButton(category.id, title: category.name)
                }
            }
        }
    }

    private func categoryButton(_ id: UUID?, title: String) -> some View {
        Button {
            selectedCategoryId = id
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedCategoryId == id ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCategoryId == id ? theme.colorPrimary : theme.colorDivider)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func productionEditor(title: String, production: Production?) -> some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Nome piatto", text: $newProductionName)
                    Picker("Categoria", selection: Binding(
                        get: { newProductionCategoryId ?? scopedCategories.first?.id ?? UUID() },
                        set: { newProductionCategoryId = $0 }
                    )) {
                        ForEach(scopedCategories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }
                Section("Durata conservazione (indicativa)") {
                    let categoryName = scopedCategories.first(where: { $0.id == newProductionCategoryId })?.name ?? ""
                    let suggested = ProductionShelfLifeDefaults.days(
                        forName: newProductionName.isEmpty ? " " : newProductionName,
                        categoryName: categoryName
                    )
                    Text("Suggerita HACCP: \(suggested) gg in frigo (+2/+4 °C). Valida con il tuo manuale.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                    ShelfLifeDaysNumberField(days: $shelfLifeDays, label: "Durata")
                }
            }
            .navigationTitle(title)
            .onChange(of: newProductionName) { _, _ in
                guard production == nil else { return }
                let categoryName = scopedCategories.first(where: { $0.id == newProductionCategoryId })?.name ?? ""
                shelfLifeDays = ProductionShelfLifeDefaults.days(forName: newProductionName, categoryName: categoryName)
            }
            .onChange(of: newProductionCategoryId) { _, _ in
                guard production == nil else { return }
                let categoryName = scopedCategories.first(where: { $0.id == newProductionCategoryId })?.name ?? ""
                shelfLifeDays = ProductionShelfLifeDefaults.days(forName: newProductionName, categoryName: categoryName)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        showAddSheet = false
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveProduction(production) }
                        .disabled(newProductionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func rebuildPresentation() {
        presentation = ProductionCatalogPresentation.build(
            categories: scopedCategories,
            productions: scopedProductions,
            selectedCategoryId: selectedCategoryId
        )
    }

    private func requestAdd() {
        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
            newProductionName = ""
            newProductionCategoryId = selectedCategoryId ?? scopedCategories.first?.id
            let categoryName = scopedCategories.first(where: { $0.id == newProductionCategoryId })?.name ?? ""
            shelfLifeDays = ProductionShelfLifeDefaults.days(forName: "", categoryName: categoryName)
            showAddSheet = true
        }
    }

    private func requestEdit(_ production: Production) {
        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
            productionToEdit = production
            newProductionName = production.name
            newProductionCategoryId = production.categoryId
            shelfLifeDays = production.shelfLifeDays ?? production.defaultShelfLifeDays
            showEditSheet = true
        }
    }

    private func requestDelete(_ production: Production) {
        masterAuth.request(permission: .manageProductionLibrary, permissions: permissions) {
            deleteProduction(production)
        }
    }

    private func saveProduction(_ production: Production?) {
        guard let rid = appState.activeRestaurantId,
              let categoryId = newProductionCategoryId,
              let category = scopedCategories.first(where: { $0.id == categoryId }) else { return }
        guard permissions.canPerform(.manageProductionLibrary) else {
            errorMessage = "Serve l'autorizzazione MASTER."
            return
        }
        do {
            if let production {
                try service.updateProduction(
                    production,
                    name: newProductionName,
                    category: category,
                    existingProductions: scopedProductions,
                    modelContext: modelContext,
                    shelfLifeDays: shelfLifeDays
                )
                selectedProduction = production
            } else {
                try service.addProduction(
                    name: newProductionName,
                    category: category,
                    restaurantId: rid,
                    existingProductions: scopedProductions,
                    modelContext: modelContext,
                    shelfLifeDays: shelfLifeDays
                )
            }
            showAddSheet = false
            showEditSheet = false
            newProductionName = ""
            if let rid = appState.activeRestaurantId {
                dataStore.reload(context: modelContext, restaurantId: rid, force: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteProduction(_ production: Production) {
        do {
            try service.deleteProductionIfUnused(
                production,
                modelContext: modelContext
            )
            selectedProduction = nil
            if let rid = appState.activeRestaurantId {
                dataStore.reload(context: modelContext, restaurantId: rid, force: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
