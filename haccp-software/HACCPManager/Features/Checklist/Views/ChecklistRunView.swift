import SwiftUI
import SwiftData

struct ChecklistRunView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [LocalUser]
    @Query private var itemResults: [ChecklistItemResult]

    let run: ChecklistRun
    let service: ChecklistService
    @StateObject private var vm = ChecklistRunViewModel()

    private var currentUser: LocalUser? {
        users.first(where: { $0.id == appState.currentUserId })
    }

    private var scopedResults: [ChecklistItemResult] {
        itemResults
            .filter { $0.checklistRunId == run.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: run.progressPercentage, total: 100)
                .tint(progressTint)
            Text("\(completedItems)/\(totalItems) completati · \(Int(run.progressPercentage))%")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(scopedResults) { result in
                        ChecklistRunItemCard(
                            result: result,
                            onSave: { value, note in
                                save(result: result, value: value, note: note)
                            }
                        )
                    }
                }
            }

        }
        .padding(20)
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle(run.templateTitleSnapshot)
        .alert("Checklist", isPresented: Binding(get: { vm.completionError != nil }, set: { _ in vm.completionError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.completionError ?? "")
        }
    }

    private func save(result: ChecklistItemResult, value: ChecklistItemResultValue, note: String?) {
        guard let currentUser else { return }
        do {
            try service.updateItemResult(
                itemResult: result,
                result: value,
                note: note,
                user: currentUser,
                run: run,
                restaurantId: run.restaurantId,
                modelContext: modelContext
            )
        } catch {
            vm.completionError = "Salvataggio item non riuscito."
        }
    }
}

private struct ChecklistRunItemCard: View {
    let result: ChecklistItemResult
    let onSave: (ChecklistItemResultValue, String?) -> Void

    @State private var selectedValue: ChecklistItemResultValue = .pending
    @State private var note: String = ""
    @State private var initialized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.titleSnapshot).foregroundColor(.white).font(.headline)
            Picker("Esito", selection: $selectedValue) {
                Text(ChecklistItemResultValue.pass.label).tag(ChecklistItemResultValue.pass)
                Text(ChecklistItemResultValue.fail.label).tag(ChecklistItemResultValue.fail)
                Text(ChecklistItemResultValue.notApplicable.label).tag(ChecklistItemResultValue.notApplicable)
            }
            .pickerStyle(.segmented)
            if selectedValue == .fail {
                Text("Criticita")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(8)
            }
            TextField("Nota (opzionale)", text: $note)
                .textFieldStyle(.roundedBorder)
            Text("Autosalvataggio attivo")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            selectedValue = result.result
            note = result.note ?? ""
            initialized = true
        }
        .onChange(of: selectedValue) { _, _ in
            guard initialized else { return }
            onSave(selectedValue, note.isEmpty ? nil : note)
        }
        .onChange(of: note) { _, _ in
            guard initialized else { return }
            onSave(selectedValue, note.isEmpty ? nil : note)
        }
    }
}

private extension ChecklistRunView {
    var totalItems: Int { scopedResults.count }
    var completedItems: Int { scopedResults.filter { $0.result != .pending }.count }
    var progressTint: Color {
        let p = run.progressPercentage
        if p >= 100 { return .green }
        if p >= 50 { return .yellow }
        return .red
    }
}
