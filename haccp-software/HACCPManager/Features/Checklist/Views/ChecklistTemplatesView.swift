import SwiftUI

struct ChecklistTemplatesView: View {
    let templates: [ChecklistTemplate]
    let canManage: Bool
    let canExecute: Bool
    let onCreate: () -> Void
    let onStartRun: (ChecklistTemplate) -> Void
    let onEdit: (ChecklistTemplate) -> Void
    let onDelete: (ChecklistTemplate) -> Void
    let currentRole: UserRole?

    @State private var categoryFilter: ChecklistCategory?
    @State private var frequencyFilter: ChecklistFrequency?

    private var filtered: [ChecklistTemplate] {
        templates
            .filter { template in
                guard let categoryFilter else { return true }
                return template.category == categoryFilter
            }
            .filter { template in
                guard let frequencyFilter else { return true }
                return template.frequency == frequencyFilter
            }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Menu("Categoria") {
                    Button("Tutte") { categoryFilter = nil }
                    ForEach(ChecklistCategory.allCases, id: \.self) { category in
                        Button(category.label) { categoryFilter = category }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Menu("Frequenza") {
                    Button("Tutte") { frequencyFilter = nil }
                    ForEach(ChecklistFrequency.allCases, id: \.self) { frequency in
                        Button(frequency.label) { frequencyFilter = frequency }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Spacer()

                if canManage {
                    Button("Crea checklist", action: onCreate)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
            }

            if filtered.isEmpty {
                ChecklistEmptyStateView(
                    title: "Nessun modello checklist",
                    message: "Crea o attiva un modello per iniziare.",
                    actionTitle: canManage ? "Nuovo modello" : nil,
                    action: canManage ? onCreate : nil
                )
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filtered) { template in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title).foregroundColor(.white).font(.headline)
                                    Text("\(template.category.label) - \(template.frequency.label)")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                Spacer()

                                if canManage {
                                    Button {
                                        onEdit(template)
                                    } label: {
                                        Image(systemName: "pencil.circle.fill").foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    if currentRole == .master {
                                        Button {
                                            onDelete(template)
                                        } label: {
                                            Image(systemName: "trash.circle.fill").foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
}
