import Foundation

protocol EmailVerificationService {
    func sendVerificationCode(to email: String) async throws
    func verify(code: String, for email: String) async throws -> Bool
}

class MockEmailVerificationService: EmailVerificationService {
    // TODO: In futuro, collegare a un servizio API reale (SendGrid, AWS SES, o backend custom)
    // per inviare email reali agli utenti.
    
    private let mockValidCode = "123456"
    
    func sendVerificationCode(to email: String) async throws {
        // Nessun delay per la modalità sviluppo/test locale
        print("DEV: Codice di verifica generato: \(mockValidCode)")
    }
    
    func verify(code: String, for email: String) async throws -> Bool {
        return code == mockValidCode
    }
}
