import Foundation

/// Sezioni minime per audit-ready PDF (bitmask).
struct OfficialReportSectionFlags: OptionSet, Sendable {
    let rawValue: UInt32
    static let intestazione = Self(rawValue: 1 << 0)
    static let ricezioneMerci = Self(rawValue: 1 << 1)
    static let tracciabilita = Self(rawValue: 1 << 2)
    static let nonConformita = Self(rawValue: 1 << 3)
    static let auditLog = Self(rawValue: 1 << 4)
    static let riepilogo = Self(rawValue: 1 << 5)
    /// Tabellare giornaliero o sintesi mensile/annuale (contenuto strutturato oltre le singole righe).
    static let allegatoPeriodo = Self(rawValue: 1 << 6)
    static let indiceMensile = Self(rawValue: 1 << 7)
}

enum OfficialReportFlavor: Sendable {
    case giornalieroHACCPCombinato
    case giornalieroRicezione
    case giornalieroTracciabilita
    case mensileHACCPCombinato
    case annualeHACCPCombinato
    case registroNonConformitaMensile
}

enum DocumentCompletenessError: Error, LocalizedError {
    case sezioniMancanti(String)

    var errorDescription: String? {
        switch self {
        case .sezioniMancanti(let s): return s
        }
    }
}

enum DocumentCompletenessValidator {
    /// Mappa tipo/modulo documento SwiftData al flavor di validazione.
    static func reportFlavor(type: DocumentType, module: DocumentModule) -> OfficialReportFlavor? {
        switch (type, module) {
        case (.giornaliero, .haccpCombinato): return .giornalieroHACCPCombinato
        case (.giornaliero, .ricezioneMerci): return .giornalieroRicezione
        case (.giornaliero, .tracciabilita): return .giornalieroTracciabilita
        case (.settimanale, .ricezioneMerci): return .giornalieroRicezione
        case (.settimanale, .tracciabilita): return .giornalieroTracciabilita
        case (.settimanale, .haccpCombinato): return .mensileHACCPCombinato
        case (.mensile, .ricezioneMerci): return .giornalieroRicezione
        case (.mensile, .tracciabilita): return .giornalieroTracciabilita
        case (.mensile, .haccpCombinato): return .mensileHACCPCombinato
        case (.annuale, .haccpCombinato): return .annualeHACCPCombinato
        case (.mensile, .nonConformita): return .registroNonConformitaMensile
        case (.nonConformita, _): return .registroNonConformitaMensile
        default: return nil
        }
    }

    static func requiredSections(for flavor: OfficialReportFlavor) -> OfficialReportSectionFlags {
        switch flavor {
        case .giornalieroHACCPCombinato:
            return [.intestazione, .riepilogo, .nonConformita, .auditLog, .allegatoPeriodo]
        case .giornalieroRicezione:
            return [.intestazione, .ricezioneMerci, .auditLog, .riepilogo]
        case .giornalieroTracciabilita:
            return [.intestazione, .tracciabilita, .auditLog, .riepilogo]
        case .mensileHACCPCombinato:
            return [.intestazione, .riepilogo, .nonConformita, .auditLog, .allegatoPeriodo]
        case .annualeHACCPCombinato:
            return [.intestazione, .riepilogo, .allegatoPeriodo, .indiceMensile]
        case .registroNonConformitaMensile:
            return [.intestazione, .nonConformita, .auditLog, .riepilogo]
        }
    }

    static func validate(present: OfficialReportSectionFlags, flavor: OfficialReportFlavor) throws {
        let req = requiredSections(for: flavor)
        let missing = req.subtracting(present)
        guard missing.isEmpty else {
            throw DocumentCompletenessError.sezioniMancanti(
                "Sezioni obbligatorie assenti: \(describe(missing))"
            )
        }
    }

    private static func describe(_ flags: OfficialReportSectionFlags) -> String {
        var parts: [String] = []
        if flags.contains(.intestazione) { parts.append("intestazione") }
        if flags.contains(.ricezioneMerci) { parts.append("ricezione merci") }
        if flags.contains(.tracciabilita) { parts.append("tracciabilità") }
        if flags.contains(.nonConformita) { parts.append("non conformità") }
        if flags.contains(.auditLog) { parts.append("audit log") }
        if flags.contains(.riepilogo) { parts.append("riepilogo") }
        if flags.contains(.allegatoPeriodo) { parts.append("allegato periodo") }
        if flags.contains(.indiceMensile) { parts.append("indice mensile") }
        return parts.joined(separator: ", ")
    }
}
