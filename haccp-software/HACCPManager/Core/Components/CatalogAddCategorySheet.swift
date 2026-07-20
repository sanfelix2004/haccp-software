import SwiftUI

/// Sheet riutilizzabile per aggiungere una categoria di catalogo.
struct CatalogAddCategorySheet: View {
    let title: String
    let placeholder: String
    let existingNames: [String]
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField(placeholder, text: $name)
                        .textInputAutocapitalization(.words)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colorError)
                    }
                }
            }
            .navigationTitle("Nuova categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.localizedCaseInsensitiveCompare("Tutti") == .orderedSame {
            errorMessage = "«Tutti» è riservato."
            return
        }
        let exists = existingNames.contains {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
                == trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        }
        guard !exists else {
            errorMessage = "Categoria già presente."
            return
        }
        onSave(trimmed)
    }
}
