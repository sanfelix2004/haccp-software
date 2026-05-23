//
//  SettingsLegalTexts.swift
//  Testi informativi per sezione Info app.
//

import Foundation

enum SettingsLegalDocument: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case licenses
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "Termini di Servizio"
        case .privacy: return "Privacy Policy"
        case .licenses: return "Licenze Open Source"
        case .support: return "Supporto Tecnico"
        }
    }

    var icon: String {
        switch self {
        case .terms: return "doc.text.fill"
        case .privacy: return "lock.doc.fill"
        case .licenses: return "shippingbox.fill"
        case .support: return "lifepreserver.fill"
        }
    }

    var body: String {
        switch self {
        case .terms:
            return """
            HACCP Manager è un software gestionale per la registrazione operativa HACCP in locale.

            L'uso dell'app è riservato al personale autorizzato del ristorante. L'utente MASTER è responsabile della configurazione, degli accessi e del backup dei dati sul dispositivo.

            I limiti di temperatura, le soglie e i promemoria sono strumenti di supporto: restano obbligatori i controlli previsti dal proprio piano HACCP e dalla normativa applicabile.

            Romanazzi IT Solutions non è responsabile per errori di inserimento dati, mancata esecuzione dei controlli o perdita di informazioni dovuta a reset del dispositivo senza backup.
            """
        case .privacy:
            return """
            I dati HACCP (temperature, checklist, tracciabilità, documenti PDF generati) sono memorizzati principalmente sul dispositivo, nel container sicuro dell'app.

            Non vendiamo né profiliamo i dati operativi del locale. Eventuale sincronizzazione PDF su iCloud avviene solo se abilitata esplicitamente dall'utente MASTER nelle impostazioni.

            Le foto allegate ai controlli restano associate ai record sul dispositivo salvo esportazione manuale o copia cloud attivata dall'utente.

            Per richieste relative ai dati del dispositivo contattare l'amministratore MASTER del ristorante o il referente indicato in fase di installazione.
            """
        case .licenses:
            return """
            HACCP Manager utilizza componenti Apple (SwiftUI, SwiftData, Foundation) e API di sistema soggette alle licenze Apple.

            Eventuali librerie di terze parti integrate in futuro saranno elencate in questa sezione con i rispettivi testi di licenza.

            Per segnalazioni su licenze o attribuzioni mancanti: supporto@romanazzi.it
            """
        case .support:
            return """
            Prima di contattare il supporto:
            • Verifica connessione iCloud (se usi backup PDF)
            • Controlla spazio disponibile in Impostazioni → Dati e Backup
            • Assicurati di usare l'ultima versione dell'app

            Email: supporto@romanazzi.it
            Indica versione app, modello iPad e descrizione del problema.

            Orari indicativi: lun–ven 9:00–18:00 (ora italiana).
            """
        }
    }
}
