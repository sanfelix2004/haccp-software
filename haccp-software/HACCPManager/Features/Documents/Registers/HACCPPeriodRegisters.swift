import Foundation

/// Testo unificato per periodi senza movimenti (nessun dato fittizio).
enum HACCPRegisterCopy {
    static let noActivityInPeriod = "Nessuna attività registrata nel periodo."
}

/// Registro giornaliero HACCP: intervallo di un giorno sui dati SwiftData reali (vista aggregata, non file).
enum HACCPDailyRegister {}

/// Registro mensile HACCP: intervallo mensile sui dati SwiftData reali (vista aggregata, non file).
enum HACCPMonthlyRegister {}
