import SwiftUI
import UIKit

public struct ActivityTouchTracker: UIViewRepresentable {
    public var onActivity: () -> Void
    
    public func makeUIView(context: Context) -> UIView {
        let view = ActivityReportingView()
        view.onActivity = onActivity
        view.backgroundColor = .clear
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
    
    class ActivityReportingView: UIView {
        var onActivity: (() -> Void)?
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // Report activity whenever a touch is hit-tested in this view's area
            onActivity?()
            // IMPORTANT: Return nil to allow the touch to pass through to views below
            return nil
        }
    }
}

public extension View {
    func monitorActivity(action: @escaping () -> Void) -> some View {
        self.overlay(
            ActivityTouchTracker(onActivity: action)
                .allowsHitTesting(true) // We need it to receive hitTest but it returns nil
        )
    }
}
