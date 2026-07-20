import Foundation

/// Nomi ufficiali dei moduli HACCP (sidebar, dashboard, filtri storia, cartelle documenti).
enum HACCPModuleCatalog {
    static let orderedTitles: [String] = [
        "Tracciabilità",
        "Frigoriferi",
        "Controllo pulizia",
        "Abbattimento",
        "Controllo scadenze e quantità",
        "Decongelamento",
        "Controllo olio",
        "Etichette di produzione",
        "Ricezione merci",
        "HACCP combinato"
    ]

    /// Moduli operativi (senza il report combinato), stesso ordine della sidebar.
    static let operationalModuleTitles: [String] = Array(orderedTitles.dropLast())

    /// Messaggio neutro per UI non collegata ai registri (nessun dato fittizio).
    static let reportPlaceholderMessage = "Nessuna attività registrata nel periodo."
}
