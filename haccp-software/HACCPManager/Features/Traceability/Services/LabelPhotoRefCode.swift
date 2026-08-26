import Foundation

/// Codice di riferimento “foto” derivato da data/ora dello scatto.
/// Non sostituisce il lotto produzione: serve come traccia di sicurezza sul documento fotografico.
enum LabelPhotoRefCode {
    /// Formato: `F-yyyyMMdd-HHmmss` (es. `F-20260826-112345`).
    static func make(from captureDate: Date) -> String {
        formatter.string(from: captureDate)
    }

    /// Preferisce `LottoFoto.dataScatto`, altrimenti data ricevuta/creazione del record.
    static func make(
        record: TraceabilityRecord,
        lottoById: [UUID: LottoFoto]
    ) -> String {
        if let lottoId = record.lottoFotoId, let lotto = lottoById[lottoId] {
            return make(from: lotto.dataScatto)
        }
        return make(from: record.receivedAt)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "'F'-yyyyMMdd-HHmmss"
        return f
    }()
}
