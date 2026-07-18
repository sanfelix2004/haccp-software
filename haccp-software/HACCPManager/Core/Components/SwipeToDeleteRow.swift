import SwiftUI

/// Riga con swipe verso sinistra per mostrare azione elimina dedicata (funziona dentro ScrollView).
struct SwipeToDeleteRow<Content: View>: View {
    let enabled: Bool
    var deleteTitle: String = "Elimina"
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.theme) private var theme
    @State private var offset: CGFloat = 0
    @State private var isRevealed = false
    @State private var dragAxis: SwipeDragAxis = .undecided

    private let actionWidth: CGFloat = 88

    private enum SwipeDragAxis {
        case undecided
        case horizontal
        case vertical
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if enabled {
                Button {
                    settle(open: false)
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.body.weight(.semibold))
                        Text(deleteTitle)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
                .highPriorityGesture(enabled ? swipeGesture : nil)
        }
        .clipped()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if dragAxis == .undecided {
                    let width = abs(value.translation.width)
                    let height = abs(value.translation.height)
                    guard width > 6 || height > 6 else { return }
                    dragAxis = width > height * 1.15 ? .horizontal : .vertical
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
                let shouldOpen = offset < -actionWidth * 0.4
                    || value.predictedEndTranslation.width < -actionWidth * 0.8
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
