import SwiftUI
import SwiftData

struct EditChecklistTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var itemTemplates: [ChecklistItemTemplate]

    let template: ChecklistTemplate
    let service: ChecklistService

    @StateObject private var vm = ChecklistTemplateViewModel()

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Modello") {
                    TextField("Titolo", text: $vm.title)
                    TextField("Descrizione", text: $vm.description)
                    Toggle("Attiva", isOn: Binding(get: { template.isActive }, set: { template.isActive = $0 }))
                }
                Section("Attivita") {
                    ForEach($vm.items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Titolo item", text: $item.title)
                            TextField("Descrizione", text: $item.description)
                            Picker("Tipo", selection: $item.type) {
                                ForEach(ChecklistItemType.allCases, id: \.self) { type in
                                    Text(type.rawValue.replacingOccurrences(of: "_", with: " ")).tag(type)
                                }
                            }
                            Toggle("Obbligatorio", isOn: $item.isRequired)
                            Toggle("Nota obbligatoria se fallisce", isOn: $item.requiresNoteIfFailed)
                        }
                    }
                    .onDelete { indexes in
                        vm.items.remove(atOffsets: indexes)
                    }
                    Button("Aggiungi item") { vm.addItem() }
                }
            }
            .navigationTitle("Modifica checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() } }
            }
        }
        .onAppear {
            vm.title = template.title
            vm.description = template.checklistDescription
            vm.items = itemTemplates
                .filter { $0.checklistTemplateId == template.id }
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .map {
                    ChecklistItemTemplateDraft(
                        title: $0.title,
                        description: $0.itemDescription,
                        type: $0.type,
                        isRequired: $0.isRequired,
                        requiresNoteIfFailed: $0.requiresNoteIfFailed
                    )
                }
        }
    }

    private func save() {
        guard let currentUser else { return }
        guard vm.validateBeforeSave() else { return }

        template.title = vm.title
        template.checklistDescription = vm.description
        template.updatedAt = Date()

        let existing = itemTemplates.filter { $0.checklistTemplateId == template.id }
        for item in existing { modelContext.delete(item) }
        for (index, draft) in vm.items.enumerated() {
            modelContext.insert(
                ChecklistItemTemplate(
                    checklistTemplateId: template.id,
                    title: draft.title,
                    itemDescription: draft.description,
                    type: draft.type,
                    isRequired: draft.isRequired,
                    orderIndex: index,
                    requiresNoteIfFailed: draft.requiresNoteIfFailed
                )
            )
        }

        service.log(
            restaurantId: template.restaurantId,
            user: currentUser,
            action: "CHECKLIST_TEMPLATE_UPDATED",
            entityId: template.id,
            details: template.title,
            modelContext: modelContext
        )
        try? modelContext.save()
        dismiss()
    }
}
