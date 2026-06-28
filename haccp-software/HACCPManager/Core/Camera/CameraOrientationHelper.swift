import AVFoundation
import UIKit

enum CameraOrientationHelper {
    static var activeInterfaceOrientation: UIInterfaceOrientation {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           scene.interfaceOrientation != .unknown {
            return scene.interfaceOrientation
        }
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        case .portrait: return .portrait
        default: return .landscapeRight
        }
    }

    static func videoRotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait: return 90
        case .portraitUpsideDown: return 270
        case .landscapeRight: return 0
        case .landscapeLeft: return 180
        default: return 0
        }
    }

    static func applyVideoRotation(
        to connection: AVCaptureConnection,
        orientation: UIInterfaceOrientation = activeInterfaceOrientation
    ) {
        if #available(iOS 17.0, *) {
            let angle = videoRotationAngle(for: orientation)
            guard connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = captureVideoOrientation(for: orientation)
        }
    }

    private static func captureVideoOrientation(for orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .landscapeRight
        }
    }
}
