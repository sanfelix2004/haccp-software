import SwiftUI

struct DocumentItemCard: View {
    let document: DocumentItem
    let pdfExists: Bool
    let canManageDocuments: Bool
    let onOpen: () -> Void
    let onShare: () -> Void
    let onExportCSV: () -> Void
    let onExportCopy: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void

    @Environment(\.theme) private var theme

    private var displayTitle: String {
        document.title.isEmpty ? document.fileName : document.title
    }

    private var subtitle: String {
        "\(document.module.label) · \(document.type.label)"
    }

    private var metaLine: String {
        let size = ByteCountFormatter.string(fromByteCount: document.sizeInBytes, countStyle: .file)
        let date = document.generatedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(date) · \(size)"
    }

    var body: some View {
        GlassCard(elevated: true) {
            HStack(alignment: .top, spacing: theme.spacing.md) {
                Button(action: onOpen) {
                    HStack(alignment: .top, spacing: theme.spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.colorPrimary.opacity(0.12))
                                .frame(width: 44, height: 52)
                            Image(systemName: document.format == .pdf ? "doc.richtext.fill" : "doc.fill")
                                .font(.title3)
                                .foregroundStyle(theme.colorPrimary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(displayTitle)
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colorTextPrimary)
                                .lineLimit(2)

                            Text(subtitle)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)

                            Text(metaLine)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary.opacity(0.9))

                            HStack(spacing: 8) {
                                statusBadge
                                if document.isSyncedToICloud {
                                    syncBadge
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PremiumPressButtonStyle(scale: 0.99))
                .disabled(!pdfExists)
                .accessibilityLabel("Apri \(displayTitle)")

                Menu {
                    Button {
                        onOpen()
                    } label: {
                        Label("Apri PDF", systemImage: "doc.viewfinder")
                    }
                    .disabled(!pdfExists)

                    if pdfExists {
                        Button {
                            onShare()
                        } label: {
                            Label("Condividi PDF", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        onExportCSV()
                    } label: {
                        Label("Esporta CSV", systemImage: "tablecells")
                    }

                    Button {
                        onExportCopy()
                    } label: {
                        Label("Esporta copia", systemImage: "tray.and.arrow.up")
                    }

                    if canManageDocuments {
                        Divider()
                        Button {
                            onRegenerate()
                        } label: {
                            Label("Rigenera", systemImage: "arrow.clockwise")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.colorPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Azioni documento")
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch document.status {
        case .fallito:
            HACCPBadge(title: "Generazione fallita", style: .nonConforme)
        case .esportato:
            HACCPBadge(title: "Esportato", style: .info)
        default:
            if !pdfExists {
                HACCPBadge(title: "File assente", style: .warning)
            }
        }
    }

    @ViewBuilder
    private var syncBadge: some View {
        HACCPBadge(title: "Su iCloud", style: .conforme)
    }
}

struct DocumentFolderCard: View {
    let folder: DocumentFolder
    let documentCount: Int
    let latestUpdate: Date?
    let hasNew: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            GlassCard(elevated: true) {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.colorWarning.opacity(0.14))
                                .frame(width: 40, height: 40)
                            Image(systemName: "folder.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.colorWarning)
                        }
                        Spacer()
                        if hasNew {
                            HACCPBadge(title: "Nuovo", style: .nonConforme)
                        }
                        Image(systemName: "chevron.right")
                            .font(theme.typography.caption.weight(.bold))
                            .foregroundStyle(theme.colorTextSecondary.opacity(0.7))
                    }

                    Text(folder.name)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colorTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(documentCount == 0 ? "Nessun documento" : "\(documentCount) documenti")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)

                    if let latestUpdate {
                        Text("Aggiornata \(latestUpdate.formatted(date: .abbreviated, time: .shortened))")
                            .font(theme.typography.caption2)
                            .foregroundStyle(theme.colorTextSecondary.opacity(0.85))
                    }
                }
            }
        }
        .buttonStyle(PremiumPressButtonStyle(scale: 0.98))
        .accessibilityHint("Apri cartella \(folder.name)")
    }
}
