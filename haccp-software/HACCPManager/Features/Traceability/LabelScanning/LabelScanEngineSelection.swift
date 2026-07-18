import Foundation
import LabelScanningContract

/// Selezione runtime V1/V2 persistita in UserDefaults.
enum LabelScanEngineSelection: String, CaseIterable, Identifiable {
    case v1
    case v2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .v1: return "V1"
        case .v2: return "V2"
        }
    }

    private static let defaultsKey = "labelScanEngineSelection"

    static var current: LabelScanEngineSelection {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? Self.v1.rawValue
            return LabelScanEngineSelection(rawValue: raw) ?? .v1
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}
