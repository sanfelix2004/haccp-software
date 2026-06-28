import SwiftUI
import SwiftData

/// Editor ricetta: alimenti in ingresso associati a una produzione (scadenza in tracciabilità).
struct ProductionIncomingIngredientsEditorView: View {
    let production: Production

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query private var templates: [ProductTemplate]

    @State private var links: [ProductionIncomingIngredient] = []
    @State private var showAddSheet = false
    @State private var linkToEdit: ProductionIncomingIngredient?
    @State private var errorMessage: String?

    private let service = ProductionIncomingIngredientService()

    private var scopedTemplates: [ProductTemplate] {
        templates
            .filter { $0.restaurantId == production.restaurantId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableTemplates: [ProductTemplate] {
        let used = Set(links.map(\.productTemplateId))
        return scopedTemplates.filter { !used.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(production.name)
                        .font(theme.typography.subheadline.weight(.semibold))
                    Text("\(links.count) alimenti in ricetta · durata piatto: \(production.defaultShelfLifeDays) gg")
                        .font(theme.typography.caption2)
                        .foregroundStyle(theme.colorTextSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    showAddSheet = true
                } label: {
                    Label("Aggiungi", systemImage: "plus.circle.fill")
                        .font(theme.typography.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(availableTemplates.isEmpty)
            }

            if links.isEmpty {
                Text("Nessun alimento associato. Aggiungi gli ingredienti previsti dalla ricetta. La scadenza si registra in tracciabilità.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(links, id: \.id) { link in
                        ProductionIncomingIngredientRow(
                            link: link,
                            onEdit: { linkToEdit = link },
                            onDelete: { remove(link) }
                        )
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: production.id) { _, _ in reload() }
        .sheet(isPresented: $showAddSheet) {
            addIngredientSheet
        }
        .sheet(item: $linkToEdit) { link in
            editIngredientSheet(link)
        }
        .alert("Ricetta produzione", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var addIngredientSheet: some View {
        NavigationStack {
            AddProductionIncomingIngredientSheet(
                templates: availableTemplates,
                onCancel: { showAddSheet = false },
                onAdd: { template in
                    addIngredient(template: template)
                }
            )
        }
        .presentationDetents([.large])
    }

    private func editIngredientSheet(_ link: ProductionIncomingIngredient) -> some View {
        let selectable = scopedTemplates.filter { template in
            template.id == link.productTemplateId
                || !links.contains(where: { $0.productTemplateId == template.id && $0.id != link.id })
        }
        return NavigationStack {
            EditProductionIncomingIngredientSheet(
                link: link,
                availableTemplates: selectable,
                onCancel: { linkToEdit = nil },
                onSave: { template in
                    saveEdit(link: link, template: template)
                }
            )
        }
        .presentationDetents([.medium, .large])
    }

    private func reload() {
        links = service.ingredients(productionId: production.id, modelContext: modelContext)
    }

    private func addIngredient(template: ProductTemplate) {
        do {
            try service.addIngredient(
                production: production,
                template: template,
                modelContext: modelContext
            )
            showAddSheet = false
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveEdit(link: ProductionIncomingIngredient, template: ProductTemplate) {
        do {
            try service.updateTemplate(link, template: template, modelContext: modelContext)
            linkToEdit = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ link: ProductionIncomingIngredient) {
        do {
            try service.remove(link, modelContext: modelContext)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProductionIncomingIngredientRow: View {
    let link: ProductionIncomingIngredient
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(link.productNameSnapshot)
                .font(theme.typography.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Button("Modifica", action: onEdit)
                .font(theme.typography.caption.weight(.semibold))
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .font(theme.typography.caption)
        }
        .padding(12)
        .background(theme.colorSurfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AddProductionIncomingIngredientSheet: View {
    let templates: [ProductTemplate]
    let onCancel: () -> Void
    let onAdd: (ProductTemplate) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedTemplate: ProductTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Seleziona un alimento in ingresso. La scadenza si imposta in tracciabilità (etichetta o data manuale).")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)

            if templates.isEmpty {
                Text("Tutti gli alimenti disponibili sono già in ricetta.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            } else {
                ProductSelectionGridView(
                    products: templates,
                    recentProductIds: [],
                    selectedProductId: selectedTemplate?.id,
                    onSelect: { selectedTemplate = $0 }
                )
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Aggiungi alimento")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Aggiungi") {
                    guard let selectedTemplate else { return }
                    onAdd(selectedTemplate)
                }
                .disabled(selectedTemplate == nil)
            }
        }
    }
}

private struct EditProductionIncomingIngredientSheet: View {
    let link: ProductionIncomingIngredient
    let availableTemplates: [ProductTemplate]
    let onCancel: () -> Void
    let onSave: (ProductTemplate) -> Void

    @Environment(\.theme) private var theme
    @State private var selectedTemplate: ProductTemplate?

    var body: some View {
        Form {
            Section("Alimento") {
                Picker("Tipo merce", selection: Binding(
                    get: { selectedTemplate?.id ?? link.productTemplateId },
                    set: { id in selectedTemplate = availableTemplates.first { $0.id == id } }
                )) {
                    ForEach(availableTemplates) { template in
                        Text(template.name).tag(template.id)
                    }
                }
            }
        }
        .navigationTitle("Modifica ingrediente")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    let template = selectedTemplate ?? availableTemplates.first { $0.id == link.productTemplateId }
                    guard let template else { return }
                    onSave(template)
                }
            }
        }
        .onAppear {
            selectedTemplate = availableTemplates.first { $0.id == link.productTemplateId }
        }
    }
}
