import SwiftUI
import UIKit

// MARK: - Step del flusso

enum TraceabilityCaptureStep: Int, CaseIterable {
    case shoot = 1
    case label = 2
    case production = 3

    var title: String {
        switch self {
        case .shoot: "Scatta"
        case .label: "Etichetta"
        case .production: "Produzione"
        }
    }

    var icon: String {
        switch self {
        case .shoot: "camera.fill"
        case .label: "barcode.viewfinder"
        case .production: "fork.knife"
        }
    }
}

struct TraceabilityCaptureStepBar: View {
    let current: TraceabilityCaptureStep
    var sessionCount: Int = 0

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TraceabilityCaptureStep.allCases, id: \.rawValue) { step in
                stepNode(step)
                if step != .production {
                    connector(isActive: step.rawValue < current.rawValue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func stepNode(_ step: TraceabilityCaptureStep) -> some View {
        let isCurrent = step == current
        let isDone = step.rawValue < current.rawValue

        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isCurrent ? theme.colorPrimary : (isDone ? theme.colorSuccess : theme.colorDivider.opacity(0.6)))
                    .frame(width: 26, height: 26)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isCurrent ? theme.colorTextOnPrimary : theme.colorTextSecondary)
                }
            }
            if isCurrent {
                VStack(alignment: .leading, spacing: 0) {
                    Text(step.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextPrimary)
                    if step == .shoot, sessionCount > 0 {
                        Text("\(sessionCount) in sessione")
                            .font(.caption2)
                            .foregroundStyle(theme.colorTextSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? theme.colorSuccess.opacity(0.7) : theme.colorDivider.opacity(0.5))
            .frame(width: 24, height: 2)
    }
}

// MARK: - Dock sessione camera

struct TraceabilitySessionDock: View {
    let items: [LottoFoto]
    let onFinish: () -> Void
    var onDelete: ((LottoFoto) -> Void)? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onFinish) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assegna alimento")
                            .font(.subheadline.weight(.bold))
                        Text("Collega le etichette a un Alimento Produzione")
                            .font(.caption2)
                            .opacity(0.9)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [theme.colorPrimary, theme.colorPrimary.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in
                        dockThumbnail(item)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    private func dockThumbnail(_ item: LottoFoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = LottoFotoImageStorage.loadImage(at: item.thumbnailPath)
                    ?? LottoFotoImageStorage.loadImage(at: item.localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.colorPrimary.opacity(0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(theme.colorPrimary)
                        }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let onDelete {
                Button {
                    onDelete(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .accessibilityLabel("Elimina foto")
            }
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Riepilogo sessione (picker produzione)

struct TraceabilitySessionSummaryStrip: View {
    let items: [LottoFoto]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(items.count) etichette in questa sessione", systemImage: "camera.fill")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colorTextSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(items, id: \.id) { item in
                    summaryChip(item)
                }
            }
        }
        .padding(12)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryChip(_ item: LottoFoto) -> some View {
        HStack(spacing: 8) {
            Group {
                if let image = LottoFotoImageStorage.loadImage(at: item.thumbnailPath)
                    ?? LottoFotoImageStorage.loadImage(at: item.localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.colorPrimary.opacity(0.1))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(theme.colorPrimary)
                        }
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Etichetta")
                .font(theme.typography.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(8)
        .background(theme.colorBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Guida flusso hub

struct TraceabilityWorkflowGuideCard: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            workflowStep(number: 1, icon: "camera.fill", title: "Foto lotti", subtitle: "Più scatti")
            arrow
            workflowStep(number: 2, icon: "fork.knife", title: "Produzione", subtitle: "Piatto interno")
            arrow
            workflowStep(number: 3, icon: "printer.fill", title: "Etichetta", subtitle: "Stampa qui")
        }
        .padding(14)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.8), lineWidth: 1)
        )
    }

    private func workflowStep(number: Int, icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(theme.colorPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colorPrimary)
            }
            Text(title)
                .font(theme.typography.caption.weight(.bold))
                .foregroundStyle(theme.colorTextPrimary)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(theme.colorTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var arrow: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(theme.colorTextSecondary.opacity(0.5))
            .padding(.horizontal, 2)
    }
}

// MARK: - Campo ricerca compatto

struct TraceabilityInlineSearchField: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colorTextSecondary)
                .font(.caption)
            TextField(placeholder, text: $text)
                .font(theme.typography.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colorTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.colorSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
