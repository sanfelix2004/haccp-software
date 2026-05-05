import Combine
import Foundation
import SwiftData
import UIKit

@MainActor
final class OneDriveSyncService: ObservableObject {
    static let shared = OneDriveSyncService()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionExplanation: String = "OneDrive non collegato."
    @Published private(set) var lastSyncActivity: String = ""
    @Published private(set) var lastSyncActivityDate: Date?
    @Published private(set) var isAuthenticating: Bool = false

    private let session = URLSession(configuration: .default)
    private let tokenEndpoint = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
    private let deviceCodeEndpoint = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
    private let defaultScope = "offline_access Files.ReadWrite"

    private struct DeviceCodeResponse: Decodable {
        let device_code: String
        let user_code: String
        let verification_uri: String
        let expires_in: Int
        let interval: Int
        let message: String
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
    }

    private struct OneDriveTokenPayload: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    private init() {
        refreshConnectionDiagnostics()
    }

    var isAutoSyncEnabled: Bool {
        get { DocumentsUserSettings.isOneDriveAutoSyncEnabled }
        set { DocumentsUserSettings.isOneDriveAutoSyncEnabled = newValue }
    }

    var clientId: String {
        get { DocumentsUserSettings.oneDriveClientId.trimmingCharacters(in: .whitespacesAndNewlines) }
        set { DocumentsUserSettings.oneDriveClientId = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: DocumentsUserSettings.oneDriveTokenKey)
        refreshConnectionDiagnostics()
        lastSyncActivity = "OneDrive disconnesso."
        lastSyncActivityDate = Date()
    }

    func refreshConnectionDiagnostics() {
        if clientId.isEmpty {
            isConnected = false
            connectionExplanation = "Inserisci il Client ID OneDrive (Azure App Registration) per attivare la sincronizzazione automatica."
            return
        }
        guard let token = loadToken() else {
            isConnected = false
            connectionExplanation = "OneDrive non collegato. Premi «Collega OneDrive» e completa login Microsoft."
            return
        }
        isConnected = token.expiresAt > Date()
        if isConnected {
            connectionExplanation = "OneDrive collegato. I PDF nuovi vengono caricati automaticamente quando l'app è attiva."
        } else {
            connectionExplanation = "Sessione OneDrive scaduta. Premi «Collega OneDrive» per rinnovare l'accesso."
        }
    }

    func connectInteractive() async {
        guard !isAuthenticating else { return }
        guard !clientId.isEmpty else {
            lastSyncActivity = "Client ID OneDrive mancante."
            lastSyncActivityDate = Date()
            refreshConnectionDiagnostics()
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let device = try await requestDeviceCode()
            lastSyncActivity = "Apri \(device.verification_uri) e inserisci codice: \(device.user_code)"
            lastSyncActivityDate = Date()
            if let url = URL(string: device.verification_uri) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
            let token = try await pollForToken(deviceCode: device.device_code, expiresIn: device.expires_in, interval: max(device.interval, 3))
            saveToken(accessToken: token.access_token, refreshToken: token.refresh_token ?? "", expiresIn: token.expires_in)
            refreshConnectionDiagnostics()
            lastSyncActivity = "OneDrive collegato con successo."
            lastSyncActivityDate = Date()
        } catch {
            refreshConnectionDiagnostics()
            lastSyncActivity = "Errore collegamento OneDrive: \(error.localizedDescription)"
            lastSyncActivityDate = Date()
        }
    }

    func syncDocument(_ item: DocumentItem, modelContext: ModelContext) async {
        guard isAutoSyncEnabled else { return }
        guard item.localFilePresent, item.format == .pdf else { return }
        guard let relative = item.iCloudRelativePath?.trimmingCharacters(in: CharacterSet(charactersIn: "/")), !relative.isEmpty else { return }

        do {
            let accessToken = try await validAccessToken()
            let localURL = URL(fileURLWithPath: item.filePath)
            let data = try await Task.detached(priority: .utility) { try Data(contentsOf: localURL) }.value
            try await upload(data: data, path: relative, accessToken: accessToken)
            item.isSyncedToICloud = true
            item.status = .sincronizzato
            try? modelContext.save()
            lastSyncActivity = "Caricato su OneDrive: «\(item.fileName)»"
            lastSyncActivityDate = Date()
        } catch {
            item.isSyncedToICloud = false
            try? modelContext.save()
            lastSyncActivity = "Errore upload OneDrive «\(item.fileName)»: \(error.localizedDescription)"
            lastSyncActivityDate = Date()
        }
    }

    func syncAllPendingDocuments(items: [DocumentItem], modelContext: ModelContext) async {
        guard isAutoSyncEnabled else { return }
        guard isConnected else {
            refreshConnectionDiagnostics()
            return
        }
        let pending = items.filter { $0.localFilePresent && $0.format == .pdf && !$0.isSyncedToICloud }
        guard !pending.isEmpty else { return }
        var ok = 0
        var ko = 0
        for item in pending {
            await syncDocument(item, modelContext: modelContext)
            if item.isSyncedToICloud { ok += 1 } else { ko += 1 }
        }
        lastSyncActivity = "Sync OneDrive completata: \(ok) ok, \(ko) errori."
        lastSyncActivityDate = Date()
    }

    func scheduleSyncAfterGeneration(for itemId: UUID, modelContext: ModelContext) {
        Task { @MainActor in
            let all = (try? modelContext.fetch(FetchDescriptor<DocumentItem>())) ?? []
            guard let item = all.first(where: { $0.id == itemId }) else { return }
            await syncDocument(item, modelContext: modelContext)
        }
    }

    // MARK: - Private

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        var req = URLRequest(url: deviceCodeEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(urlEncode(clientId))&scope=\(urlEncode(defaultScope))"
        req.httpBody = body.data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "OneDriveAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device code request fallita."])
        }
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForToken(deviceCode: String, expiresIn: Int, interval: Int) async throws -> TokenResponse {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        while Date() < deadline {
            do {
                return try await requestTokenWithDeviceCode(deviceCode)
            } catch {
                let ns = error as NSError
                if let code = ns.userInfo["oauth_error"] as? String,
                   code == "authorization_pending" || code == "slow_down" {
                    try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                    continue
                }
                throw error
            }
        }
        throw NSError(domain: "OneDriveAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Tempo login scaduto."])
    }

    private func requestTokenWithDeviceCode(_ deviceCode: String) async throws -> TokenResponse {
        var req = URLRequest(url: tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type=urn:ietf:params:oauth:grant-type:device_code",
            "client_id=\(urlEncode(clientId))",
            "device_code=\(urlEncode(deviceCode))"
        ].joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "OneDriveAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Risposta token non valida."])
        }
        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error"] as? String {
            throw NSError(domain: "OneDriveAuth", code: http.statusCode, userInfo: [
                "oauth_error": errorCode,
                NSLocalizedDescriptionKey: (json["error_description"] as? String) ?? "Errore OAuth."
            ])
        }
        throw NSError(domain: "OneDriveAuth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Errore token OneDrive."])
    }

    private func refreshAccessToken(_ refreshToken: String) async throws -> TokenResponse {
        var req = URLRequest(url: tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type=refresh_token",
            "client_id=\(urlEncode(clientId))",
            "refresh_token=\(urlEncode(refreshToken))",
            "scope=\(urlEncode(defaultScope))"
        ].joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "OneDriveAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Refresh token OneDrive fallito."])
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func validAccessToken() async throws -> String {
        guard var token = loadToken() else {
            throw NSError(domain: "OneDriveAuth", code: 5, userInfo: [NSLocalizedDescriptionKey: "OneDrive non collegato."])
        }
        if token.expiresAt.timeIntervalSinceNow > 120 {
            return token.accessToken
        }
        let refreshed = try await refreshAccessToken(token.refreshToken)
        let refreshValue = refreshed.refresh_token ?? token.refreshToken
        saveToken(accessToken: refreshed.access_token, refreshToken: refreshValue, expiresIn: refreshed.expires_in)
        token = loadToken()!
        refreshConnectionDiagnostics()
        return token.accessToken
    }

    private func upload(data: Data, path: String, accessToken: String) async throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me/drive/root:/\(encodedPath):/content") else {
            throw NSError(domain: "OneDriveUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "URL upload OneDrive non valida."])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 else {
            throw NSError(domain: "OneDriveUpload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Upload OneDrive non riuscito."])
        }
    }

    private func saveToken(accessToken: String, refreshToken: String, expiresIn: Int) {
        let payload = OneDriveTokenPayload(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(expiresIn - 30, 30)))
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: DocumentsUserSettings.oneDriveTokenKey)
        }
    }

    private func loadToken() -> OneDriveTokenPayload? {
        guard let data = UserDefaults.standard.data(forKey: DocumentsUserSettings.oneDriveTokenKey) else { return nil }
        return try? JSONDecoder().decode(OneDriveTokenPayload.self, from: data)
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
