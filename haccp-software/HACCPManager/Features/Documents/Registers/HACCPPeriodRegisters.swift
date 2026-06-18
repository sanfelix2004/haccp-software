import Foundation

/// Testi unificati per registri e documenti ufficiali.
enum HACCPRegisterCopy {
    static let noActivityInPeriod = "Nessuna attività registrata nel periodo indicato."
    static let noCriticalEvents = "Nessuna criticità o non conformità rilevata nel periodo."
    static let noNonConformities = "Nessuna non conformità registrata nel periodo."
    static let notAvailable = "N.d."
    static let conformChecklist = "Conforme"
    static let officialDocumentBanner = "REGISTRO HACCP — DOCUMENTO UFFICIALE"
    static let dataSourceNote = "Dati estratti dall'archivio digitale HACCP Manager alla data di generazione."
}

/// Registro giornaliero HACCP: intervallo di un giorno sui dati SwiftData reali (vista aggregata, non file).
enum HACCPDailyRegister {}

/// Registro mensile HACCP: intervallo mensile sui dati SwiftData reali (vista aggregata, non file).
enum HACCPMonthlyRegister {}
