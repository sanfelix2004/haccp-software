import SwiftUI

/// Card uniforme per le sezioni impostazioni.
struct SettingsPanelCard<Content: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colorTextPrimary)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colorTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.6), lineWidth: 1)
        )
    }
}

/// Sezione espandibile per opzioni avanzate o secondarie.
struct SettingsExpandableCard<Content: View>: View {
    let title: String
    var caption: String? = nil
    var startsExpanded: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme
    @State private var isExpanded: Bool

    init(
        title: String,
        caption: String? = nil,
        startsExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.startsExpanded = startsExpanded
        self.content = content
        _isExpanded = State(initialValue: startsExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colorTextPrimary)
                        if let caption, !caption.isEmpty {
                            Text(caption)
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colorTextSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.colorTextSecondary)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, theme.spacing.md)
            }
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.6), lineWidth: 1)
        )
    }
}

/// Campo numerico compatto in riga.
struct SettingsCompactNumberRow: View {
    let title: String
    @Binding var value: Double
    let unit: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(theme.typography.subheadline)
                .foregroundStyle(theme.colorTextPrimary)
            Spacer(minLength: 8)
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(theme.typography.body.weight(.semibold).monospacedDigit())
                .frame(maxWidth: 64)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.colorSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(unit)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colorTextSecondary)
                .frame(width: 28, alignment: .leading)
        }
    }
}

/// Stepper compatto con etichetta.
struct SettingsCompactStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = ""

    @Environment(\.theme) private var theme

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .font(theme.typography.subheadline)
                    .foregroundStyle(theme.colorTextPrimary)
                Spacer()
                Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                    .font(theme.typography.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colorTextSecondary)
            }
        }
    }
}
