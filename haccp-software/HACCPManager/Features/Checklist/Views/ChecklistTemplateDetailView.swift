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
                Text(template.title).font(.largeTitle.bold()).foregroundColor(.white)
                Text(template.checklistDescription).foregroundColor(.gray)
                Text("\(template.category.label) - \(template.frequency.label)")
                    .foregroundColor(.white.opacity(0.75))
                Divider().overlay(Color.white.opacity(0.1))
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).foregroundColor(.white).font(.headline)
                        Text(item.itemDescription).foregroundColor(.gray).font(.caption)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationTitle("Dettaglio modello")
    }
}
