import SwiftUI
import SwiftData

/// Catalogo alimenti in ingresso (template) per Ricezione merci e Decongelamento.
struct IncomingFoodCatalogManagementView: View {
    var embeddedInSettings: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var session: RestaurantSessionContext

    @ObservedObject private var dataStore = ModuleStoreRegistry.shared.incomingFoodCatalog

    /// `nil` = Tutti
    @State private var selectedCategoryName: String?
    @State private var selectedTemplate: ProductTemplate?
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showAddCategorySheet = false
    @State private var templateToEdit: ProductTemplate?
    @State private var newName = ""
    @State private var newCategoryName = ""
    @State private var errorMessage: String?
    @State private var masterAuth = MasterAuthCoordinator()
    @State private var presentation = IncomingFoodCatalogPresentation.empty

    private let catalogService = ProductTemplateCatalogService()

    private var scopedTemplates: [ProductTemplate] {
        dataStore.templates
    }

    private var scopedCategories: [IncomingFoodCategory] {
        dataStore.categories.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var visibleTemplates: [ProductTemplate] {
        presentation.flatProducts
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
                    message: "Il catalogo alimenti è legato al ristorante attivo.",
                    actionTitle: nil
                ))
                .padding(theme.spacing.screenPadding)
            } else if dataStore.isLoading && scopedTemplates.isEmpty && scopedCategories.isEmpty {
                ProgressView("Caricamento catalogo…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                catalogScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(embeddedInSettings ? "" : "Alimenti in ingresso")
        .haccpControlTint()
        .moduleScreenLoad(restaurantId: appState.activeRestaurantId) {
            guard let rid = appState.activeRestaurantId else { return }
            dataStore.reload(context: modelContext, restaurantId: rid)
        }
        .onChange(of: dataStore.dataRevision) { _, _ in
            rebuildPresentation()
        }
        .onChange(of: selectedCategoryName) { _, _ in
            rebuildPresentation()
        }
        .onAppear {
            rebuildPresentation()
        }
        .sheet(isPresented: $showAddSheet) { templateEditor(title: "Nuovo alimento", template: nil) }
        .sheet(isPresented: $showEditSheet) {
            if let template = templateToEdit {
                templateEditor(title: "Modifica alimento", template: template)
            }
        }
        .sheet(isPresented: $showAddCategorySheet) {
            CatalogAddCategorySheet(
                title: "Categoria alimenti",
                placeholder: "Es. Latticini, Spezie…",
                existingNames: scopedCategories.map(\.name),
                onSave: { name in
                    saveNewCategory(name)
                },
                onCancel: { showAddCategorySheet = false }
            )
        }
        .masterAuthCover(coordinator: masterAuth, master: session.masterUser)
        .alert("Alimenti in ingresso", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
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
                        title: "Alimenti in ingresso",
                        subtitle: "Tipi di merce per Ricezione merci e Decongelamento (non sono i piatti del menu)",
                        systemImage: "shippingbox.fill",
                        help: ModuleHelpLibrary.sidebar(.incomingFoodCatalog)
                    )
                }

                DashboardCardView(
                    title: "Gestione alimenti",
                    subtitle: "Materie prime e prodotti in ingresso · PIN MASTER per l'operatore"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        actionBar
                        categoryTabs

                        if let selected = selectedTemplate {
                            selectedBanner(selected)
                        }

                        Text("\(visibleTemplates.count) alimenti")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)

                        if visibleTemplates.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Catalogo vuoto",
                                message: "Aggiungi il primo alimento per questa categoria.",
                                actionTitle: "Aggiungi alimento"
                            )) {
                                requestAdd()
                            }
                        } else {
                            ProductSelectionGridView(
                                layout: presentation,
                                selectedProductId: selectedTemplate?.id,
                                onSelect: { selectedTemplate = $0 }
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
            PrimaryButton(title: "Aggiungi alimento", icon: "plus.circle.fill") { requestAdd() }
            SecondaryButton(title: "Categoria", icon: "folder.badge.plus") { requestAddCategory() }
            if let selected = selectedTemplate {
                SecondaryButton(title: "Modifica", icon: "pencil") { requestEdit(selected) }
                Button(role: .destructive) { requestDelete(selected) } label: {
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

    private func selectedBanner(_ template: ProductTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.colorSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("Selezionato: \(template.name)")
                    .font(theme.typography.subheadline.bold())
                Text(template.categoryDisplayName)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
                Text("Scadenza in tracciabilità")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            Spacer(minLength: 0)
            Button("Deseleziona") { selectedTemplate = nil }
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
                    categoryButton(category.name, title: category.name)
                }
            }
        }
    }

    private func categoryButton(_ name: String?, title: String) -> some View {
        let isSelected = selectedCategoryName == name
            || (name == nil && selectedCategoryName == nil)
        return Button {
            selectedCategoryName = name
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? theme.colorPrimary : theme.colorDivider)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func templateEditor(title: String, template: ProductTemplate?) -> some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Nome alimento", text: $newName)
                    Picker("Categoria", selection: $newCategoryName) {
                        ForEach(scopedCategories) { cat in
                            Text(cat.name).tag(cat.name)
                        }
                    }
                }
                Section {
                    Text("La scadenza non si imposta qui: viene registrata in tracciabilità (etichetta o data manuale).")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        showAddSheet = false
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveTemplate(template) }
                        .disabled(
                            newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || newCategoryName.isEmpty
                        )
                }
            }
        }
    }

    private func rebuildPresentation() {
        presentation = IncomingFoodCatalogPresentation.build(
            templates: scopedTemplates,
            categories: scopedCategories,
            selectedCategoryName: selectedCategoryName
        )
    }

    private func requestAdd() {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            newName = ""
            newCategoryName = selectedCategoryName
                ?? scopedCategories.first?.name
                ?? GoodsCategory.refrigerated.rawValue
            showAddSheet = true
        }
    }

    private func requestAddCategory() {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            showAddCategorySheet = true
        }
    }

    private func saveNewCategory(_ name: String) {
        guard let rid = appState.activeRestaurantId else { return }
        do {
            let category = try catalogService.addCategory(
                name: name,
                restaurantId: rid,
                existingCategories: scopedCategories,
                modelContext: modelContext
            )
            showAddCategorySheet = false
            selectedCategoryName = category.name
            dataStore.reload(context: modelContext, restaurantId: rid, force: true)
            HapticManager.shared.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            showAddCategorySheet = false
        }
    }

    private func requestEdit(_ template: ProductTemplate) {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            templateToEdit = template
            newName = template.name
            newCategoryName = template.categoryRaw
            showEditSheet = true
        }
    }

    private func requestDelete(_ template: ProductTemplate) {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            deleteTemplate(template)
        }
    }

    private func saveTemplate(_ template: ProductTemplate?) {
        guard let rid = appState.activeRestaurantId else { return }
        guard permissions.canPerform(.manageIncomingFoodCatalog) else {
            errorMessage = "Serve l'autorizzazione MASTER."
            return
        }
        do {
            if let template {
                try catalogService.updateTemplate(
                    template,
                    name: newName,
                    categoryName: newCategoryName,
                    existing: scopedTemplates,
                    modelContext: modelContext,
                    shelfLifeDays: nil
                )
                selectedTemplate = template
            } else {
                try catalogService.addTemplate(
                    name: newName,
                    categoryName: newCategoryName,
                    restaurantId: rid,
                    existing: scopedTemplates,
                    modelContext: modelContext,
                    shelfLifeDays: nil
                )
            }
            showAddSheet = false
            showEditSheet = false
            newName = ""
            dataStore.reload(context: modelContext, restaurantId: rid, force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTemplate(_ template: ProductTemplate) {
        do {
            try catalogService.deleteTemplateIfUnused(
                template,
                modelContext: modelContext
            )
            selectedTemplate = nil
            dataStore.reload(context: modelContext, restaurantId: appState.activeRestaurantId, force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
