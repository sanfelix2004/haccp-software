import SwiftUI

/// Riga con swipe verso sinistra per mostrare azione elimina (funziona dentro ScrollView).
struct SwipeToDeleteRow<Content: View>: View {
    let enabled: Bool
    let deleteTitle: String
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme
    @State private var offset: CGFloat = 0
    @State private var isRevealed = false
    @State private var dragAxis: SwipeDragAxis = .undecided

    private let actionWidth: CGFloat = 96

    private enum SwipeDragAxis {
        case undecided
        case horizontal
        case vertical
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if enabled {
                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.body.weight(.semibold))
                        Text(deleteTitle)
                            .font(.caption2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(theme.colorError)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deleteTitle)
            }

            content()
                .offset(x: offset)
                .gesture(enabled ? swipeGesture : nil)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                if dragAxis == .undecided {
                    let width = abs(value.translation.width)
                    let height = abs(value.translation.height)
                    guard width > 8 || height > 8 else { return }
                    dragAxis = width > height * 1.25 ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                let proposed = (isRevealed ? -actionWidth : 0) + value.translation.width
                offset = min(0, max(-actionWidth, proposed))
            }
            .onEnded { value in
                defer { dragAxis = .undecided }
                guard dragAxis == .horizontal else {
                    settle(open: isRevealed)
                    return
                }
                let shouldOpen = offset < -actionWidth * 0.45
                    || value.predictedEndTranslation.width < -actionWidth
                settle(open: shouldOpen)
            }
    }

    private func settle(open: Bool) {
        isRevealed = open
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            offset = open ? -actionWidth : 0
        }
    }
}
