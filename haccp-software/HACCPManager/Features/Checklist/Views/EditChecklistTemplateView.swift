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
                    Picker("Categoria", selection: $vm.category) {
                        ForEach(ChecklistCategory.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    Picker("Frequenza", selection: $vm.frequency) {
                        ForEach(ChecklistFrequency.allCases.filter { $0 != .custom }, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    Toggle("Attiva", isOn: Binding(get: { template.isActive }, set: { template.isActive = $0 }))
                    if !template.isCleaningBridge {
                        TextField("Area / zona (opzionale)", text: $vm.areaTag)
                    }
                }

                if vm.frequency.isScheduledCycle {
                    ChecklistScheduleFormSection(
                        frequency: $vm.frequency,
                        scheduledHour: $vm.scheduledHour,
                        scheduledMinute: $vm.scheduledMinute,
                        scheduleWeekday: $vm.scheduleWeekday,
                        scheduleDayOfMonth: $vm.scheduleDayOfMonth,
                        scheduleMonth: $vm.scheduleMonth
                    )
                }

                ChecklistBulkPassFormSection(
                    allowsBulkPass: $vm.allowsBulkPass,
                    bulkPassTitle: $vm.bulkPassTitle,
                    itemCount: vm.items.count
                )

                Section("Attività") {
                    ForEach($vm.items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Titolo item", text: $item.title)
                            TextField("Descrizione", text: $item.description)
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
        .onAppear(perform: loadFromTemplate)
    }

    private func loadFromTemplate() {
        vm.title = template.title
        vm.description = template.checklistDescription
        vm.category = template.category
        vm.frequency = template.frequency
        vm.scheduledHour = template.scheduledHour ?? 9
        vm.scheduledMinute = template.scheduledMinute ?? 0
        vm.scheduleWeekday = template.scheduleWeekday ?? ChecklistSchedulePicker.defaultWeekday()
        vm.scheduleDayOfMonth = template.scheduleDayOfMonth ?? ChecklistSchedulePicker.defaultDayOfMonth()
        vm.scheduleMonth = template.scheduleMonth ?? 1
        vm.allowsBulkPass = template.supportsBulkPass
        vm.bulkPassTitle = template.bulkPassTitle ?? ""
        vm.areaTag = template.areaTag ?? ""
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

    private func save() {
        guard let currentUser else { return }
        guard vm.validateBeforeSave() else { return }

        do {
            try service.updateTemplate(
                template,
                title: vm.title,
                description: vm.description,
                category: vm.category,
                frequency: vm.frequency,
                scheduledHour: vm.frequency.isScheduledCycle ? vm.scheduledHour : nil,
                scheduledMinute: vm.frequency.isScheduledCycle ? vm.scheduledMinute : nil,
                scheduleWeekday: vm.frequency == .weekly ? vm.scheduleWeekday : nil,
                scheduleDayOfMonth: (vm.frequency == .monthly || vm.frequency == .annual) ? vm.scheduleDayOfMonth : nil,
                scheduleMonth: vm.frequency == .annual ? vm.scheduleMonth : nil,
                allowsBulkPass: vm.allowsBulkPass && vm.items.count >= 2,
                bulkPassTitle: vm.bulkPassTitle.isEmpty ? nil : vm.bulkPassTitle,
                areaTag: vm.areaTag.isEmpty ? nil : vm.areaTag,
                isActive: template.isActive,
                items: vm.items,
                user: currentUser,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            vm.validationError = "Salvataggio non riuscito."
        }
    }
}
