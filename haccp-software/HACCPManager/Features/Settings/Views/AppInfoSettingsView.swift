import SwiftUI

struct AppInfoSettingsView: View {
    @State private var presentedDocument: SettingsLegalDocument?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            VStack(spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.colorTextOnPrimary)
                    .frame(width: 72, height: 72)
                    .background(theme.colorPrimary)
                    .cornerRadius(16)

                Text(AppVersionService.appName)
                    .font(.title3.weight(.bold))
                Text(AppVersionService.currentVersion)
                    .font(.caption)
                    .foregroundStyle(theme.colorTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            SettingsPanelCard(title: "Documenti legali") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(SettingsLegalDocument.allCases) { document in
                        InfoLinkRow(
                            title: document.title,
                            subtitle: document.subtitle,
                            icon: document.icon
                        ) {
                            presentedDocument = document
                        }
                        if document != SettingsLegalDocument.allCases.last {
                            Divider().padding(.vertical, 4)
                        }
                    }
                }
            }

            Text("Dati HACCP sul dispositivo. Documenti aggiornati al \(LegalConstants.lastUpdated).")
                .font(.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(ThemeManager.shared.colorTextSecondary)
                    .frame(width: 22)
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
            .padding(.vertical, 6)
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
