import SwiftUI

enum RecipeIngredientPickerStyle {
    case chips
    case largeButtons
}

/// Badge ingredienti ricetta non ancora associati — un tocco per assegnare.
struct RecipeIngredientQuickPicker: View {
    let options: [RecipeIngredientOption]
    var style: RecipeIngredientPickerStyle = .chips
    let onSelect: (RecipeIngredientOption) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        if options.isEmpty {
            Text("Tutti gli alimenti previsti sono già associati.")
                .font(theme.typography.caption2)
                .foregroundStyle(theme.colorTextSecondary)
        } else {
            switch style {
            case .chips:
                chipsPicker
            case .largeButtons:
                largeButtonsPicker
            }
        }
    }

    private var chipsPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    chipButton(option)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var largeButtonsPicker: some View {
        HStack(spacing: 10) {
            ForEach(Array(options.prefix(4).enumerated()), id: \.element.id) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.name)
                        .font(theme.typography.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(largeButtonColor(index))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Assegna \(option.name)")
            }
        }
    }

    private func chipButton(_ option: RecipeIngredientOption) -> some View {
        Button {
            onSelect(option)
        } label: {
            Text(option.name)
                .font(theme.typography.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.colorPrimary.opacity(0.14))
                .foregroundStyle(theme.colorPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.colorPrimary.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Assegna \(option.name)")
    }

    private func largeButtonColor(_ index: Int) -> Color {
        switch index % 3 {
        case 0: return Color(red: 0.18, green: 0.45, blue: 0.82)
        case 1: return Color(red: 0.86, green: 0.68, blue: 0.12)
        default: return Color(red: 0.78, green: 0.22, blue: 0.22)
        }
    }
}
