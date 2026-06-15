//
//  HACCPZoomablePhoto.swift
//  Anteprima foto con pinch-to-zoom e ingrandimento a schermo intero.
//

import SwiftUI
import UIKit

// MARK: - UIKit pinch zoom

struct PinchZoomImageView: UIViewRepresentable {
    let image: UIImage
    var minimumZoomScale: CGFloat = 1
    var maximumZoomScale: CGFloat = 5

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}

// MARK: - Schermo intero

struct HACCPPhotoZoomViewer: View {
    let image: UIImage
    var title: String = "Foto"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                PinchZoomImageView(image: image, maximumZoomScale: 6)
                    .ignoresSafeArea()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .foregroundStyle(theme.colorTextOnPrimary)
                }
            }
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Miniatura tappabile

struct HACCPZoomablePhotoThumbnail: View {
    let image: UIImage
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 8
    var zoomTitle: String = "Foto"

    @State private var showZoom = false
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            showZoom = true
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(theme.colorDivider, lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: max(9, size * 0.18), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ingrandisci foto")
        .fullScreenCover(isPresented: $showZoom) {
            HACCPPhotoZoomViewer(image: image, title: zoomTitle)
        }
    }
}

// MARK: - Anteprima dopo scatto (pinch + schermo intero)

struct HACCPZoomablePhotoPreview: View {
    let image: UIImage
    var height: CGFloat = 260
    var zoomTitle: String = "Anteprima foto"

    @State private var showFullscreen = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            PinchZoomImageView(image: image, maximumZoomScale: 5)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.colorDivider, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        showFullscreen = true
                    } label: {
                        Label("Schermo intero", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }

            Text("Pizzica per ingrandire · tocca l’icona per schermo intero")
                .font(.caption2)
                .foregroundStyle(theme.colorTextSecondary)
                .multilineTextAlignment(.center)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            HACCPPhotoZoomViewer(image: image, title: zoomTitle)
        }
    }
}

// MARK: - Convenience

extension HACCPZoomablePhotoThumbnail {
    init?(data: Data, size: CGFloat = 56, cornerRadius: CGFloat = 8, zoomTitle: String = "Foto") {
        guard let image = UIImage(data: data) else { return nil }
        self.init(image: image, size: size, cornerRadius: cornerRadius, zoomTitle: zoomTitle)
    }
}

extension HACCPZoomablePhotoPreview {
    init?(data: Data, height: CGFloat = 260, zoomTitle: String = "Anteprima foto") {
        guard let image = UIImage(data: data) else { return nil }
        self.init(image: image, height: height, zoomTitle: zoomTitle)
    }
}
