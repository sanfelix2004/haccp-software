import Foundation

/// Preferenze utente per la sincronizzazione documenti (non SwiftData).
enum DocumentsUserSettings {
    /// Solo PDF: copia nel container iCloud Drive dopo generazione mensile / su richiesta.
    static let iCloudPDFSyncEnabledKey = "documents_icloud_pdf_sync_enabled"
    static let oneDriveAutoSyncEnabledKey = "documents_onedrive_auto_sync_enabled"
    static let oneDriveClientIdKey = "documents_onedrive_client_id"
    static let oneDriveTokenKey = "documents_onedrive_token_payload"

    private static func iCloudContactEmailKey(restaurantId: UUID) -> String {
        "documents_icloud_contact_email.\(restaurantId.uuidString)"
    }

    private static func lastMonthlyICloudSyncKey(restaurantId: UUID) -> String {
        "documents_icloud_last_monthly_sync.\(restaurantId.uuidString)"
    }

    static var isICloudPDFSyncEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: iCloudPDFSyncEnabledKey) != nil else { return true }
            return defaults.bool(forKey: iCloudPDFSyncEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: iCloudPDFSyncEnabledKey) }
    }

    static var isOneDriveAutoSyncEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: oneDriveAutoSyncEnabledKey) != nil else { return true }
            return defaults.bool(forKey: oneDriveAutoSyncEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: oneDriveAutoSyncEnabledKey) }
    }

    static var oneDriveClientId: String {
        get { UserDefaults.standard.string(forKey: oneDriveClientIdKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: oneDriveClientIdKey) }
    }

    /// Email di riferimento per backup iCloud (idealmente uguale all'account iCloud del dispositivo).
    static func iCloudContactEmail(restaurantId: UUID, restaurantEmailFallback: String = "") -> String {
        let stored = UserDefaults.standard.string(forKey: iCloudContactEmailKey(restaurantId: restaurantId))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty { return stored }
        let fallback = restaurantEmailFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback
    }

    static func setICloudContactEmail(_ email: String, restaurantId: UUID) {
        UserDefaults.standard.set(
            EmailValidator.normalized(email),
            forKey: iCloudContactEmailKey(restaurantId: restaurantId)
        )
    }

    static func lastMonthlyICloudSync(restaurantId: UUID) -> Date? {
        UserDefaults.standard.object(forKey: lastMonthlyICloudSyncKey(restaurantId: restaurantId)) as? Date
    }

    static func setLastMonthlyICloudSync(_ date: Date, restaurantId: UUID) {
        UserDefaults.standard.set(date, forKey: lastMonthlyICloudSyncKey(restaurantId: restaurantId))
    }
}
