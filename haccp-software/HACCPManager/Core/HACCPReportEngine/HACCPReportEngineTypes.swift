//
//  HACCPReportEngineTypes.swift
//  HACCP Manager — Report Engine
//
//  Tipi condivisi dal motore report: periodo, tipo report, conformità, severità.
//  Non duplica i tipi dell'archivio documenti (DocumentType / DocumentModule) ma li
//  affianca con un'astrazione di livello superiore usata da `HACCPReportEngine`.
//

import Foundation

// MARK: - Periodo di rendicontazione

/// Periodo di rendicontazione canonico dell'engine.
/// Mappabile bidirezionalmente da/verso `DocumentType` (compatibilità con archivio esistente).
enum HACCPReportPeriod: String, Codable, CaseIterable, Identifiable, Hashable {
    case daily       = "DAILY"
    case weekly      = "WEEKLY"
    case monthly     = "MONTHLY"
    case yearly      = "YEARLY"
    case nonConformity = "NON_CONFORMITY"
    case audit       = "AUDIT"
    case temperature = "TEMPERATURE"
    case productions = "PRODUCTIONS"
    case traceability = "TRACEABILITY_FULL"
    case combined    = "COMBINED_FULL"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Giornaliero"
        case .weekly: return "Settimanale"
        case .monthly: return "Mensile"
        case .yearly: return "Annuale"
        case .nonConformity: return "Non conformità"
        case .audit: return "Audit"
        case .temperature: return "Temperature"
        case .productions: return "Produzioni"
        case .traceability: return "Tracciabilità completa"
        case .combined: return "HACCP completo"
        }
    }

    /// Rappresentazione corta per nomi file (es. `2026-05-02_v1`).
    var fileTag: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .nonConformity: return "NonConformity"
        case .audit: return "Audit"
        case .temperature: return "Temperature"
        case .productions: return "Productions"
        case .traceability: return "Traceability"
        case .combined: return "Combined"
        }
    }

    /// Mappa il periodo verso il `DocumentType` esistente (per riusare l'archivio).
    var legacyDocumentType: DocumentType {
        switch self {
        case .daily: return .giornaliero
        case .weekly: return .settimanale
        case .monthly, .productions, .temperature, .audit, .traceability: return .mensile
        case .yearly, .combined: return .annuale
        case .nonConformity: return .nonConformita
        }
    }
}

// MARK: - Conformità e severità

/// Livello di conformità globale di un report (semaforo HACCP).
enum HACCPConformityLevel: String, Codable, CaseIterable {
    case conforme   = "CONFORME"
    case attenzione = "ATTENZIONE"
    case critico    = "CRITICO"
    case nonValutato = "NON_VALUTATO"

    var label: String {
        switch self {
        case .conforme: return "Conforme"
        case .attenzione: return "Attenzione"
        case .critico: return "Critico"
        case .nonValutato: return "Non valutato"
        }
    }

    var trafficLightHex: String {
        switch self {
        case .conforme: return "#34C759"
        case .attenzione: return "#FFCC00"
        case .critico: return "#FF3B30"
        case .nonValutato: return "#8E8E93"
        }
    }
}

/// Severità di un evento HACCP (audit / non conformità).
enum HACCPEventSeverity: String, Codable, CaseIterable {
    case info     = "INFO"
    case warning  = "WARNING"
    case high     = "HIGH"
    case critical = "CRITICAL"

    var label: String {
        switch self {
        case .info: return "Informativa"
        case .warning: return "Attenzione"
        case .high: return "Alta"
        case .critical: return "Critica"
        }
    }

    var weight: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

// MARK: - Tipi di operazione audit

/// Operazione effettuata su una entità HACCP (per audit trail).
enum HACCPAuditAction: String, Codable, CaseIterable {
    case create        = "CREATE"
    case update        = "UPDATE"
    case delete        = "DELETE"
    case generate      = "GENERATE"
    case regenerate    = "REGENERATE"
    case export        = "EXPORT"
    case cloudSync     = "CLOUD_SYNC"
    case acknowledge   = "ACKNOWLEDGE"
    case sign          = "SIGN"
    case verify        = "VERIFY"

    var label: String {
        switch self {
        case .create: return "Creazione"
        case .update: return "Modifica"
        case .delete: return "Eliminazione"
        case .generate: return "Generazione"
        case .regenerate: return "Rigenerazione"
        case .export: return "Esportazione"
        case .cloudSync: return "Sync iCloud"
        case .acknowledge: return "Presa visione"
        case .sign: return "Firma"
        case .verify: return "Verifica"
        }
    }
}

// MARK: - Metriche aggregate (UI dashboard + footer PDF)

/// Statistiche aggregate del periodo (esposte alla dashboard + serializzate in snapshot).
struct HACCPReportEngineStats: Codable, Hashable {
    var totalReports: Int
    var generatedToday: Int
    var pendingCloudSync: Int
    var syncedToCloud: Int
    var openNonConformities: Int
    var temperatureAlerts: Int
    var conformityAverage: Double // 0...1
    var lastGeneratedAt: Date?

    static let zero = HACCPReportEngineStats(
        totalReports: 0,
        generatedToday: 0,
        pendingCloudSync: 0,
        syncedToCloud: 0,
        openNonConformities: 0,
        temperatureAlerts: 0,
        conformityAverage: 1.0,
        lastGeneratedAt: nil
    )

    var conformityPercent: Int {
        let clamped = min(max(conformityAverage, 0), 1)
        return Int((clamped * 100).rounded())
    }

    var conformityLevel: HACCPConformityLevel {
        guard totalReports > 0 else { return .nonValutato }
        if openNonConformities == 0 && temperatureAlerts == 0 && conformityAverage >= 0.95 { return .conforme }
        if openNonConformities > 3 || conformityAverage < 0.75 { return .critico }
        return .attenzione
    }
}

// MARK: - Errori engine

enum HACCPReportEngineError: LocalizedError {
    case noActiveRestaurant
    case noActiveUser
    case persistenceUnavailable
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noActiveRestaurant: return "Nessun ristorante attivo selezionato."
        case .noActiveUser: return "Sessione utente non disponibile."
        case .persistenceUnavailable: return "Persistenza SwiftData non disponibile."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

// MARK: - Identificazione report

/// Identificativo logico stabile (indipendente da UUID) di un report.
/// Esempio: `HACCP-DAILY-Ricezione_2026-05-02`.
struct HACCPReportIdentity: Hashable, Codable {
    let period: HACCPReportPeriod
    let module: DocumentModule
    let periodStart: Date

    init(period: HACCPReportPeriod, module: DocumentModule, periodStart: Date) {
        self.period = period
        self.module = module
        self.periodStart = periodStart
    }

    /// Chiave deterministica usabile come prefisso di file e indice in dizionari.
    var logicalKey: String {
        let ts = Int(periodStart.timeIntervalSince1970)
        return "HACCP-\(period.fileTag.uppercased())-\(module.rawValue)-\(ts)"
    }
}
