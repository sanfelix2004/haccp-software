import SwiftUI
import SwiftData

/// Catalogo alimenti in ingresso (template) per Ricezione merci e Decongelamento.
struct IncomingFoodCatalogManagementView: View {
    var embeddedInSettings: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @Query private var users: [LocalUser]
    @Query private var templates: [ProductTemplate]
    @Query private var receipts: [GoodsReceivingRecord]
    @Query private var defrostRecords: [DefrostRecord]

    @State private var selectedCategory: GoodsCategory = .all
    @State private var selectedTemplate: ProductTemplate?
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var templateToEdit: ProductTemplate?
    @State private var newName = ""
    @State private var newCategory: GoodsCategory = .frozenProducts
    @State private var errorMessage: String?
    @State private var masterAuth = MasterAuthCoordinator()

    private let catalogService = ProductTemplateCatalogService()

    private var scopedTemplates: [ProductTemplate] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return templates.filter { $0.restaurantId == rid }
    }

    private var scopedReceipts: [GoodsReceivingRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return receipts.filter { $0.restaurantId == rid }
    }

    private var scopedDefrostRecords: [DefrostRecord] {
        guard let rid = appState.activeRestaurantId else { return [] }
        return defrostRecords.filter { $0.restaurantId == rid }
    }

    private var filteredTemplates: [ProductTemplate] {
        let base = scopedTemplates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard selectedCategory != .all else { return base }
        return base.filter { $0.category == selectedCategory }
    }

    private var currentUser: LocalUser? {
        users.first { $0.id == appState.currentUserId }
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
            } else {
                catalogScroll
            }
        }
        .background(theme.colorBackground.ignoresSafeArea())
        .navigationTitle(embeddedInSettings ? "" : "Alimenti in ingresso")
        .haccpControlTint()
        .onAppear(perform: ensureDefaults)
        .onChange(of: appState.activeRestaurantId) { _, _ in ensureDefaults() }
        .sheet(isPresented: $showAddSheet) { templateEditor(title: "Nuovo alimento", template: nil) }
        .sheet(isPresented: $showEditSheet) {
            if let template = templateToEdit {
                templateEditor(title: "Modifica alimento", template: template)
            }
        }
        .masterAuthCover(coordinator: masterAuth, master: users.first(where: { $0.role == .master }))
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

                        Text("\(filteredTemplates.count) alimenti")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorTextSecondary)

                        if filteredTemplates.isEmpty {
                            DashboardEmptyStateView(state: .init(
                                title: "Catalogo vuoto",
                                message: "Aggiungi il primo alimento per questa categoria.",
                                actionTitle: "Aggiungi alimento"
                            )) {
                                requestAdd()
                            }
                        } else {
                            ProductSelectionGridView(
                                products: filteredTemplates,
                                recentProductIds: [],
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
                Text(template.category.rawValue)
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
                ForEach(GoodsCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? theme.colorPrimary : theme.colorDivider)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func templateEditor(title: String, template: ProductTemplate?) -> some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("Nome alimento", text: $newName)
                    Picker("Categoria", selection: $newCategory) {
                        ForEach(GoodsCategory.allCases.filter { $0 != .all }) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
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
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func requestAdd() {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            newName = ""
            newCategory = selectedCategory == .all ? .frozenProducts : selectedCategory
            showAddSheet = true
        }
    }

    private func requestEdit(_ template: ProductTemplate) {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            templateToEdit = template
            newName = template.name
            newCategory = template.category
            showEditSheet = true
        }
    }

    private func requestDelete(_ template: ProductTemplate) {
        masterAuth.request(permission: .manageIncomingFoodCatalog, permissions: permissions) {
            deleteTemplate(template)
        }
    }

    private func ensureDefaults() {
        guard let rid = appState.activeRestaurantId else { return }
        ProductTemplateSeeder.ensureTemplates(restaurantId: rid, modelContext: modelContext)
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
                    category: newCategory,
                    existing: scopedTemplates,
                    modelContext: modelContext
                )
                selectedTemplate = template
            } else {
                try catalogService.addTemplate(
                    name: newName,
                    category: newCategory,
                    restaurantId: rid,
                    existing: scopedTemplates,
                    modelContext: modelContext
                )
            }
            showAddSheet = false
            showEditSheet = false
            newName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTemplate(_ template: ProductTemplate) {
        do {
            try catalogService.deleteTemplateIfUnused(
                template,
                receipts: scopedReceipts,
                defrostRecords: scopedDefrostRecords,
                modelContext: modelContext
            )
            selectedTemplate = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
