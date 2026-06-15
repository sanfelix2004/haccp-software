import SwiftUI
import SwiftData
import PhotosUI

struct OilCheckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = OilCheckViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    let point: OilPoint
    let restaurantId: UUID
    let user: LocalUser
    let service: OilControlService
    let onSaved: () -> Void

    private var settings: HACCPSettings {
        SettingsStorageService.shared.haccp
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Punto olio") {
                    Text(point.name)
                    DatePicker("Data e ora controllo", selection: $vm.checkedAt)
                }

                Section("Controllo") {
                    Picker("Stato olio", selection: $vm.selectedStatus) {
                        ForEach(OilStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    TextField("Composti polari % (opzionale)", text: $vm.polarCompoundsText)
                        .keyboardType(.decimalPad)
                    TextField("Temperatura °C (opzionale)", text: $vm.temperatureText)
                        .keyboardType(.decimalPad)
                    Picker("Azione effettuata", selection: $vm.actionTaken) {
                        ForEach(OilAction.allCases) { action in
                            Text(action.label).tag(action)
                        }
                    }
                    if !vm.validationMessage.isEmpty {
                        Text(vm.validationMessage)
                            .font(.caption)
                            .foregroundStyle(vm.selectedStatus.isCritical ? .red : .secondary)
                    }
                    if vm.hasInvalidNumericInput {
                        Text("Inserisci valori numerici validi oppure lascia il campo vuoto.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Note") {
                    TextField("Note / motivazione / azione correttiva", text: $vm.notes, axis: .vertical)
                        .lineLimit(3...6)
                    if vm.selectedStatus.isCritical {
                        Text("Nota e azione correttiva sono obbligatorie per stati critici.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if settings.oilNonCompliancePhotoRequired && vm.selectedStatus.isCritical {
                    Section("Foto non conformità") {
                        let hasPhoto = vm.photoData != nil
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(hasPhoto ? "Cambia foto" : "Allega foto obbligatoria", systemImage: hasPhoto ? "checkmark.circle.fill" : "camera.fill")
                        }
                        if let data = vm.photoData,
                           let preview = HACCPZoomablePhotoPreview(data: data, height: 200, zoomTitle: "Foto controllo olio") {
                            preview
                        }
                    }
                }
            }
            .navigationTitle("Nuovo controllo olio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Conferma") { save() }
                        .disabled(!canSubmit)
                }
            }
            .onAppear {
                vm.updateValidation(settings: settings)
            }
            .onChange(of: vm.polarCompoundsText) { _, _ in vm.updateValidation(settings: settings) }
            .onChange(of: vm.selectedStatus) { _, _ in vm.updateValidation(settings: settings) }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    vm.photoData = try? await item?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard !vm.hasInvalidNumericInput else { return false }
        if vm.selectedStatus.isCritical {
            let note = vm.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty, vm.actionTaken != .nessunaAzione else { return false }
            if settings.oilNonCompliancePhotoRequired {
                return vm.photoData != nil
            }
        }
        return true
    }

    private func save() {
        do {
            _ = try service.saveCheck(
                point: point,
                checkedAt: vm.checkedAt,
                selectedStatus: vm.selectedStatus,
                polarCompoundsValue: vm.polarCompoundsValue(),
                temperature: vm.temperatureValue(),
                actionTaken: vm.actionTaken,
                notes: vm.notes,
                photoData: vm.photoData,
                user: user,
                restaurantId: restaurantId,
                settings: settings,
                modelContext: modelContext
            )
            onSaved()
            dismiss()
        } catch {
            // La disabilitazione del bottone copre i casi previsti; qui manteniamo la sheet aperta.
        }
    }
}
