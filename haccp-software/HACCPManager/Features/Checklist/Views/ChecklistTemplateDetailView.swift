import SwiftUI
import SwiftData

struct ChecklistTemplateDetailView: View {
    let template: ChecklistTemplate
    @Query private var itemTemplates: [ChecklistItemTemplate]

    private var items: [ChecklistItemTemplate] {
        itemTemplates
            .filter { $0.checklistTemplateId == template.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(template.title).font(.largeTitle.bold()).foregroundStyle(ThemeManager.shared.colorTextPrimary)
                Text(template.checklistDescription).foregroundStyle(ThemeManager.shared.colorTextSecondary)
                Text("\(template.category.label) - \(template.frequency.label)")
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                Divider().overlay(ThemeManager.shared.colorDivider)
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).foregroundStyle(ThemeManager.shared.colorTextPrimary).font(.headline)
                        Text(item.itemDescription).foregroundStyle(ThemeManager.shared.colorTextSecondary).font(.caption)
                    }
                    .padding(10)
                    .background(ThemeManager.shared.colorSurface)
                    .cornerRadius(10)
                }
            }
            .padding(20)
        }
        .background(ThemeManager.shared.colorBackground.ignoresSafeArea())
        .navigationTitle("Dettaglio modello")
    }
}
