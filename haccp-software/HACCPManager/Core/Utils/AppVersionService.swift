import Foundation

public struct AppVersionService {
    public static var currentVersion: String {
        // 1. Try to read from Info.plist (Marketing Version)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        // 2. Try to read from embedded VERSION file as fallback
        let fileVersion: String? = {
            if let path = Bundle.main.path(forResource: "VERSION", ofType: nil),
               let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }()
        
        let finalVersion = version ?? fileVersion ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Versione \(finalVersion) (Build \(build))"
    }
    
    public static var appName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "HACCP Manager"
    }
}
