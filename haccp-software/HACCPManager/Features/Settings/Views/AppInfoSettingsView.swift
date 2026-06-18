import SwiftUI

struct AppInfoSettingsView: View {
    @State private var presentedDocument: SettingsLegalDocument?

    var body: some View {
        VStack(spacing: 32) {

            VStack(spacing: 16) {
                Image(systemName: "app.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ThemeManager.shared.colorTextOnPrimary)
                    .frame(width: 80, height: 80).background(Color.red)
                    .cornerRadius(18)

                VStack(spacing: 4) {
                    Text(AppVersionService.appName)
                        .font(.title2)
                        .fontWeight(.black)
                    Text(AppVersionService.currentVersion)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(SettingsLegalDocument.allCases) { document in
                    InfoLinkRow(
                        title: document.title,
                        subtitle: document.subtitle,
                        icon: document.icon
                    ) {
                        presentedDocument = document
                    }
                    if document != SettingsLegalDocument.allCases.last {
                        Divider().background(ThemeManager.shared.colorDivider)
                    }
                }
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 12) {
                Text("DOCUMENTAZIONE")
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.red)

                Text("Conformità e privacy")
                    .font(.headline)

                Text("Documenti aggiornati al \(LegalConstants.lastUpdated). L'App tratta i dati HACCP principalmente sul dispositivo. Consulta Informativa Privacy, Cookie e Tecnologie e Note Legali per gli obblighi GDPR e HACCP applicabili al tuo locale.")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    .lineSpacing(4)
            }
            .padding()
            .background(ThemeManager.shared.colorSurface)
            .cornerRadius(16)
        }
        .sheet(item: $presentedDocument) { document in
            SettingsLegalDocumentSheet(document: document)
        }
    }
}

struct InfoLinkRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLegalDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: SettingsLegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(document.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.colorTextSecondary)

                    Text(.init(document.body))
                        .font(.body)
                        .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding()
            }
            .background(ThemeManager.shared.colorBackground)
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
