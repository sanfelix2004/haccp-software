import Foundation

/// Versione app: file `VERSION` in bundle (sincronizzato da root in build) + Info.plist.
public struct AppVersionService {

    private static let versionResourceName = "VERSION"

    /// Numero versione marketing (es. 1.1.8).
    public static var marketingVersion: String {
        readBundledVersionFile() ?? plistString("CFBundleShortVersionString") ?? "1.0.0"
    }

    /// Build number da Info.plist.
    public static var buildNumber: String {
        plistString("CFBundleVersion") ?? "1"
    }

    /// Testo formattato per UI (Impostazioni, Info app, splash).
    public static var currentVersion: String {
        "Versione \(marketingVersion) (Build \(buildNumber))"
    }

    public static var appName: String {
        plistString("CFBundleDisplayName") ?? "HACCP Manager"
    }

    // MARK: - Private

    private static func readBundledVersionFile() -> String? {
        guard let path = Bundle.main.path(forResource: versionResourceName, ofType: nil),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func plistString(_ key: String) -> String? {
        Bundle.main.infoDictionary?[key] as? String
    }
}
