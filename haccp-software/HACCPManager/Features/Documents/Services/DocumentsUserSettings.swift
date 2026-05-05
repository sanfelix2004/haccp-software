import Foundation

/// Preferenze utente per la sincronizzazione documenti (non SwiftData).
enum DocumentsUserSettings {
    /// Solo PDF: copia nel container iCloud Drive dopo generazione / su richiesta.
    static let iCloudPDFSyncEnabledKey = "documents_icloud_pdf_sync_enabled"
    static let oneDriveAutoSyncEnabledKey = "documents_onedrive_auto_sync_enabled"
    static let oneDriveClientIdKey = "documents_onedrive_client_id"
    static let oneDriveTokenKey = "documents_onedrive_token_payload"

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
}
