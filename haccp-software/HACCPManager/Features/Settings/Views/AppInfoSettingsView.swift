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
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
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

                    LegalMarkdownView(text: document.body)
                        .textSelection(.enabled)
                }
                .padding(20)
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

struct TableBlockView: View {
    let lines: [String]

    var body: some View {
        let parsedRows = parseTable(lines)
        if parsedRows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    ForEach(0..<parsedRows.count, id: \.self) { rowIndex in
                        let cols = parsedRows[rowIndex]
                        GridRow {
                            ForEach(0..<cols.count, id: \.self) { colIndex in
                                let cell = cols[colIndex]
                                let isHeader = rowIndex == 0
                                Text(.init(cell))
                                    .font(isHeader ? .caption.weight(.bold) : .body)
                                    .foregroundStyle(isHeader ? ThemeManager.shared.colorTextSecondary : ThemeManager.shared.colorTextPrimary)
                                    .padding(.vertical, 4)
                            }
                        }
                        if rowIndex < parsedRows.count - 1 {
                            Divider()
                                .background(ThemeManager.shared.colorDivider)
                        }
                    }
                }
                .padding(14)
                .background(ThemeManager.shared.colorSurfaceElevated)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeManager.shared.colorDivider, lineWidth: 1)
                )
            }
            .padding(.vertical, 8)
        }
    }

    private func parseTable(_ lines: [String]) -> [[String]] {
        var rows: [[String]] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { continue }
            if trimmed.contains("---|") || trimmed.contains("--- |") {
                continue
            }
            let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            var cols = parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if cols.first?.isEmpty == true { cols.removeFirst() }
            if cols.last?.isEmpty == true { cols.removeLast() }
            rows.append(cols)
        }
        return rows
    }
}

struct LegalMarkdownView: View {
    let text: String

    enum Block: Identifiable {
        var id: UUID { UUID() }
        case heading1(String)
        case heading2(String)
        case heading3(String)
        case bullet(String)
        case numbered(String, String)
        case table([String])
        case paragraph(String)
        case divider
    }

    var body: some View {
        let blocks = parseBlocks(text)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<blocks.count, id: \.self) { index in
                renderBlock(blocks[index])
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .heading1(let title):
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .heading2(let title):
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .heading3(let title):
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body.weight(.bold))
                    .foregroundStyle(ThemeManager.shared.colorAccent)
                Text(.init(content))
                    .font(.body)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .numbered(let num, let content):
            HStack(alignment: .top, spacing: 8) {
                Text(num)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.colorAccent)
                Text(.init(content))
                    .font(.body)
                    .foregroundStyle(ThemeManager.shared.colorTextPrimary)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .table(let lines):
            TableBlockView(lines: lines)
        case .paragraph(let content):
            Text(.init(content))
                .font(.body)
                .foregroundStyle(ThemeManager.shared.colorTextPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .divider:
            Divider()
                .background(ThemeManager.shared.colorDivider)
                .padding(.vertical, 8)
        }
    }

    private func parseBlocks(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        let lines = markdown.components(separatedBy: .newlines)
        
        var currentTableLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("|") {
                currentTableLines.append(trimmed)
                continue
            } else {
                if !currentTableLines.isEmpty {
                    blocks.append(.table(currentTableLines))
                    currentTableLines.removeAll()
                }
            }
            
            if trimmed.isEmpty {
                continue
            }
            
            if trimmed == "—" {
                blocks.append(.divider)
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.heading1(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.heading2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                blocks.append(.heading3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("- ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("* ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else if let numEndIndex = trimmed.firstIndex(of: "."),
                      numEndIndex < trimmed.endIndex,
                      trimmed.prefix(upTo: numEndIndex).allSatisfy({ $0.isNumber }),
                      !trimmed.prefix(upTo: numEndIndex).isEmpty {
                let num = String(trimmed.prefix(through: numEndIndex))
                let contentStartIndex = trimmed.index(numEndIndex, offsetBy: 1)
                let content = trimmed.suffix(from: contentStartIndex).trimmingCharacters(in: .whitespaces)
                blocks.append(.numbered(num, content))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }
        
        if !currentTableLines.isEmpty {
            blocks.append(.table(currentTableLines))
        }
        
        return blocks
    }
}
