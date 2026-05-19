import SwiftUI

struct ChecklistHistoryView: View {
    let runs: [ChecklistRun]
    let templates: [ChecklistTemplate]
    @StateObject var vm: ChecklistHistoryViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                DatePicker("Da", selection: $vm.fromDate, displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                Menu("Categoria") {
                    Button("Tutte") { vm.categoryFilter = nil }
                    ForEach(ChecklistCategory.allCases, id: \.self) { c in
                        Button(c.label) { vm.categoryFilter = c }
                    }
                }
                .buttonStyle(.bordered)
                .tint(ThemeManager.shared.colorPrimary)
            }

            let filtered = vm.filteredRuns(runs: runs, templates: templates)
            if filtered.isEmpty {
                ChecklistEmptyStateView(
                    title: "Nessuna esecuzione",
                    message: "Lo storico checklist apparira qui.",
                    actionTitle: nil
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filtered) { run in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(run.templateTitleSnapshot).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                                        .font(.caption)
                                }
                                Spacer()
                                Text(run.status.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(run.status.color.opacity(0.25))
                                    .cornerRadius(8)
                            }
                            .padding(12)
                            .background(ThemeManager.shared.colorSurface)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
}
