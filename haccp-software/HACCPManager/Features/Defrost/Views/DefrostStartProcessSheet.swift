import SwiftUI
import SwiftData

struct DefrostStartProcessSheet: View {
    let subject: KitchenProcessSubject
    let restaurantId: UUID
    let user: LocalUser
    let onSaved: () -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Bindable private var settingsStorage = SettingsStorageService.shared

    @State private var method: DefrostMethod = .frigorifero
    @State private var initialTemperature = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    private let service = DefrostService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionSpacing) {
                    DashboardCardView(
                        title: "Alimento scelto",
                        subtitle: "Dettagli dell'alimento selezionato"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(subject.productName)
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colorTextPrimary)
                            
                            if let lot = subject.lotNumber, !lot.isEmpty {
                                Label("Lotto: \(lot)", systemImage: "tag")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                            
                            if let cat = subject.categoryName, !cat.isEmpty {
                                Label("Categoria: \(cat)", systemImage: "folder")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colorTextSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    DashboardCardView(
                        title: "Parametri di decongelamento",
                        subtitle: "Indica dove lo decongeli e la temperatura iniziale"
                    ) {
                        VStack(spacing: 14) {
                            Picker("Metodo", selection: $method) {
                                ForEach(DefrostMethod.allCases) { m in
                                    Text(m.label).tag(m)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("Temperatura iniziale °C *", text: $initialTemperature)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)

                            Text("Il timer parte quando premi Avvia, non prima.")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Fine prevista: \(method.expectedEndAt(from: Date(), settings: settingsStorage.haccp).formatted(date: .abbreviated, time: .shortened)) · max \(method.recommendedDurationHours(settings: settingsStorage.haccp)) h")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("Note (opzionale)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle("Avvia decongelamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Avvia") { save() }
                        .disabled(Double(initialTemperature.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
            .alert("Decongelamento", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        var draft = DefrostNewDraft.from(subject: subject)
        draft.method = method
        draft.initialTemperature = initialTemperature
        draft.notes = notes
        do {
            _ = try service.startDefrost(
                draft: draft,
                restaurantId: restaurantId,
                user: user,
                settings: settingsStorage.haccp,
                modelContext: modelContext
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
