import Foundation

enum HACCPAppBuildVersion {
    static var marketingAndBuild: String {
        let bundle = Bundle.main
        let v = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }
}
