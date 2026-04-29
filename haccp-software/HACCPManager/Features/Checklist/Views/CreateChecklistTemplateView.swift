import SwiftUI
import SwiftData

struct CreateChecklistTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var users: [LocalUser]
    @Query private var restaurants: [Restaurant]

    @StateObject private var vm = ChecklistTemplateViewModel()
    let service: ChecklistService

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }
    private var restaurantId: UUID? {
        appState.activeRestaurantId ?? restaurants.first?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    TextField("Titolo", text: $vm.title)
                    TextField("Descrizione", text: $vm.description)
                    Picker("Categoria", selection: $vm.category) {
                        ForEach(ChecklistCategory.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    Picker("Frequenza", selection: $vm.frequency) {
                        ForEach(ChecklistFrequency.allCases, id: \.self) { f in
                            Text(f.label).tag(f)
                        }
                    }
                }

                Section("Programmazione") {
                    Stepper("Ora: \(vm.scheduledHour)", value: $vm.scheduledHour, in: 0...23)
                    Stepper("Minuti: \(vm.scheduledMinute)", value: $vm.scheduledMinute, in: 0...59)
                }

                Section("Item checklist") {
                    ForEach($vm.items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Titolo item", text: $item.title)
                            TextField("Descrizione item", text: $item.description)
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
            .navigationTitle("Nuova checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                }
            }
            .alert("Errore", isPresented: Binding(get: { vm.validationError != nil }, set: { _ in vm.validationError = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.validationError ?? "")
            }
        }
        .onAppear {
            if vm.items.isEmpty {
                vm.addItem()
            }
        }
    }

    private func save() {
        guard vm.validateBeforeSave() else { return }
        guard let currentUser, let restaurantId else { return }
        do {
            _ = try service.createTemplate(
                restaurantId: restaurantId,
                title: vm.title,
                description: vm.description,
                category: vm.category,
                frequency: vm.frequency,
                scheduledHour: vm.scheduledHour,
                scheduledMinute: vm.scheduledMinute,
                createdBy: currentUser,
                items: vm.items,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            vm.validationError = "Salvataggio modello fallito."
        }
    }
}
