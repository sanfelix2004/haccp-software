import SwiftUI

struct BlastChillingRecordSheet: View {
    let production: Production
    let existingRecord: BlastChillingRecord?
    let operatorName: String
    let validationService: BlastChillingValidationService
    let onCancel: () -> Void
    let onStart: (Date, Double, Double) -> Void
    let onComplete: (BlastChillingRecord, Date, Double, String?, String?) -> Void

    @StateObject private var vm = BlastChillingRecordViewModel()

    private var isCompletion: Bool { existingRecord != nil }

    private var validation: BlastChillingValidationOutcome {
        if let existingRecord {
            return validationService.validateCompletion(
                startedAt: existingRecord.startedAt,
                endedAt: vm.endedAt,
                finalTemperature: vm.finalTemperature,
                targetTemperature: existingRecord.targetTemperature,
                notes: vm.notes,
                correctiveAction: vm.correctiveAction
            )
        }
        return validationService.validateStart(
            startedAt: vm.startedAt,
            initialTemperature: vm.initialTemperature
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(isCompletion ? "Termina abbattimento: \(production.name)" : "Inizia abbattimento: \(production.name)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Categoria: \(production.categoryNameSnapshot) · Operatore: \(operatorName)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        if let existingRecord {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inizio registrato")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(existingRecord.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundColor(.white)
                            }
                            DatePicker("Fine", selection: $vm.endedAt)
                                .foregroundColor(.white)
                        } else {
                            DatePicker("Inizio", selection: $vm.startedAt)
                                .foregroundColor(.white)
                        }
                    }

                    HStack(spacing: 10) {
                        if let existingRecord {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Temperatura iniziale")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(existingRecord.initialTemperature, specifier: "%.1f") °C")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            temperatureField(title: "Temperatura finale", text: vm.finalTemperatureText, field: .final)
                        } else {
                            temperatureField(title: "Temperatura iniziale", text: vm.initialTemperatureText, field: .initial)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Soglia")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\((existingRecord?.targetTemperature ?? vm.targetTemperature), specifier: "%.1f") °C")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                    }

                    keypad

                    Text(isCompletion ? validation.status.label : "In corso")
                        .font(.headline)
                        .foregroundColor(validation.status == .conforme ? .green : .orange)
                    if let message = validation.message {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if isCompletion {
                        TextField("Note", text: $vm.notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        TextField("Azione correttiva", text: $vm.correctiveAction, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                        if validation.requiresCorrectiveAction {
                            Text("Nota e azione correttiva sono obbligatorie perché la temperatura finale supera la soglia.")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(hex: "#0A0A0A").ignoresSafeArea())
            .navigationTitle(isCompletion ? "Fine abbattimento" : "Inizio abbattimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullare", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCompletion ? "Termina" : "Inizia") {
                        if let existingRecord {
                            guard let final = vm.finalTemperature else { return }
                            onComplete(existingRecord, vm.endedAt, final, vm.notes, vm.correctiveAction)
                        } else {
                            guard let initial = vm.initialTemperature else { return }
                            onStart(vm.startedAt, initial, vm.targetTemperature)
                        }
                    }
                    .disabled(!validation.canSubmit)
                }
            }
            .onAppear {
                vm.reset()
                if existingRecord != nil {
                    vm.activeTemperatureField = .final
                }
            }
        }
    }

    private func temperatureField(title: String, text: String, field: BlastChillingRecordViewModel.TemperatureField) -> some View {
        Button {
            vm.activeTemperatureField = field
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(text.isEmpty ? "--.- °C" : "\(text) °C")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(10)
            .background(vm.activeTemperatureField == field ? Color.red.opacity(0.35) : Color.white.opacity(0.06))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var keypad: some View {
        let rows = [
            ["7", "8", "9"],
            ["4", "5", "6"],
            ["1", "2", "3"],
            ["+/-", "0", "."],
            ["C", "⌫"]
        ]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            vm.tapKey(key)
                        } label: {
                            Text(key)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}
