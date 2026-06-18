//
//  ModuleHelpLibrary.swift
//  Guide contestuali per moduli e sezioni HACCP.
//

import SwiftUI

struct ModuleHelp: Identifiable, Hashable {
    let id: String
    let title: String
    let purpose: String
    let steps: [String]
    let notes: [String]

    init(
        id: String,
        title: String,
        purpose: String,
        steps: [String],
        notes: [String] = []
    ) {
        self.id = id
        self.title = title
        self.purpose = purpose
        self.steps = steps
        self.notes = notes
    }
}

enum ModuleHelpLibrary {

    static func sidebar(_ item: SidebarItem) -> ModuleHelp {
        switch item {
        case .dashboard: return dashboard
        case .traceability: return traceability
        case .fridges: return fridges
        case .cleaningControl: return cleaningControl
        case .blastChilling: return blastChilling
        case .productionCatalog: return productionCatalog
        case .incomingFoodCatalog: return incomingFoodCatalog
        case .expiryControl: return expiryControl
        case .defrost: return defrost
        case .oilControl: return oilControl
        case .productionLabels: return productionLabels
        case .goodsReceiving: return goodsReceiving
        case .checklist: return checklist
        case .history: return history
        case .documents: return documents
        case .analytics: return analytics
        case .alerts: return alerts
        case .users: return users
        case .settings: return settings
        }
    }

    static func settings(_ section: SettingsSection) -> ModuleHelp {
        switch section {
        case .profile: return settingsProfile
        case .appearance: return settingsAppearance
        case .security: return settingsSecurity
        case .restaurant: return settingsRestaurant
        case .haccp: return settingsHACCP
        case .notifications: return settingsNotifications
        case .data: return settingsData
        case .printer: return settingsPrinter
        case .info: return settingsInfo
        }
    }

    // MARK: - Moduli

    static let dashboard = ModuleHelp(
        id: "dashboard",
        title: "Dashboard",
        purpose: "Panoramica operativa del ristorante: statistiche, accesso rapido ai moduli HACCP e strumenti di supporto.",
        steps: [
            "Controlla le card in alto per attività urgenti e registrazioni di oggi.",
            "Apri un modulo HACCP dalla griglia per registrare controlli.",
            "Usa la sezione Strumenti per documenti, grafici, storico e avvisi."
        ],
        notes: ["I badge numerici indicano elementi da completare o da verificare."]
    )

    static let traceability = ModuleHelp(
        id: "traceability",
        title: "Tracciabilità",
        purpose: "Archivio HACCP di ogni prodotto ricevuto: lotto, fornitore, scadenza e collegamenti ai piatti del menu.",
        steps: [
            "Registra prima le merci da Ricezione merci: qui compaiono automaticamente.",
            "Apri una scheda prodotto per vedere dettagli, decongelamenti e piatti associati.",
            "Associa un lotto ai piatti del catalogo quando la materia prima entra in produzione.",
            "Segna non conformità e crea etichette quando necessario."
        ],
        notes: [
            "L'eliminazione di una scheda richiede il PIN MASTER.",
            "I prodotti scaduti o respinti non sono associabili a nuove produzioni."
        ]
    )

    static let fridges = ModuleHelp(
        id: "fridges",
        title: "Frigoriferi",
        purpose: "Monitoraggio temperature di frigoriferi, freezer e abbattitori con storico e azioni correttive.",
        steps: [
            "Seleziona un dispositivo e registra la temperatura rilevata.",
            "Se il valore è fuori range, inserisci l'azione correttiva obbligatoria.",
            "Consulta lo storico per verifiche ispettive.",
            "Il MASTER configura dispositivi e limiti da questa schermata."
        ],
        notes: ["Gli avvisi temperatura compaiono anche in Avvisi."]
    )

    static let cleaningControl = ModuleHelp(
        id: "cleaning",
        title: "Controllo pulizia",
        purpose: "Piano di sanificazione per aree e attività: da fare, in ritardo e completate con evidenza HACCP.",
        steps: [
            "Completa i task del giorno toccando l'area e confermando l'esito.",
            "In caso di non conformità, registra nota e azione correttiva.",
            "Il MASTER crea aree e frequenze da Gestione aree/task.",
            "Consulta lo storico per audit e verifiche periodiche."
        ],
        notes: ["La pulizia dello storico richiede autorizzazione MASTER."]
    )

    static let blastChilling = ModuleHelp(
        id: "blast",
        title: "Abbattimento",
        purpose: "Registro del ciclo di abbattimento in negativo: temperature, tempi e conformità per ogni piatto preparato.",
        steps: [
            "Premi Nuovo abbattimento e scegli un piatto dal Catalogo piatti.",
            "Inserisci la temperatura iniziale e avvia il timer.",
            "Al termine registra temperatura finale, note e firma operatore.",
            "Gli abbattimenti in corso sono visibili nell'overlay in basso a destra."
        ],
        notes: [
            "Il catalogo piatti si gestisce da Catalogo piatti nel menu laterale.",
            "Un solo abbattimento in corso per stesso piatto."
        ]
    )

    static let productionCatalog = ModuleHelp(
        id: "catalog",
        title: "Catalogo piatti",
        purpose: "Elenco centralizzato dei piatti/preparazioni del menu (Alici, Baccalà, …) usato in Abbattimento e Tracciabilità.",
        steps: [
            "Filtra per categoria con i tab in alto.",
            "Tocca un piatto per selezionarlo, poi Modifica o Elimina.",
            "Usa Aggiungi piatto per inserire una nuova voce con categoria.",
            "Le modifiche sono subito disponibili negli altri moduli."
        ],
        notes: [
            "Aggiunta, modifica ed eliminazione richiedono PIN MASTER per l'operatore.",
            "Un piatto già usato nello storico abbattimento non può essere eliminato."
        ]
    )

    static let incomingFoodCatalog = ModuleHelp(
        id: "incoming-food",
        title: "Alimenti in ingresso",
        purpose: "Catalogo delle materie prime e prodotti in ingresso (surgelati, freschi, …) usato in Ricezione merci e Decongelamento.",
        steps: [
            "Filtra per categoria merce con i tab in alto.",
            "Tocca un alimento per selezionarlo, poi Modifica o Elimina.",
            "Usa Aggiungi alimento per inserire un nuovo tipo di prodotto.",
            "I template compaiono in Ricezione merci e nel decongelamento."
        ],
        notes: [
            "Non confondere con il Catalogo piatti: qui ci sono le materie prime, non i piatti del menu.",
            "Un alimento già usato in ricezioni o decongelamenti non può essere eliminato."
        ]
    )

    static let expiryControl = ModuleHelp(
        id: "expiry",
        title: "Controllo scadenze",
        purpose: "Vista dedicata alle scadenze dei prodotti tracciati, con alert per lotti in scadenza o scaduti.",
        steps: [
            "Controlla le card riepilogative in alto (scaduti, oggi, in scadenza).",
            "Usa filtri e ricerca per trovare un lotto specifico.",
            "Intervieni sui prodotti critici: tocca un lotto scaduto per registrare ritiro o scarto.",
            "In Tracciabilità puoi anche segnare non conformità o eliminare la scheda (PIN MASTER)."
        ],
        notes: ["I dati provengono da Tracciabilità e Ricezione merci."]
    )

    static let defrost = ModuleHelp(
        id: "defrost",
        title: "Decongelamento",
        purpose: "Tracciamento dei cicli di decongelamento con metodo, durata e temperatura finale.",
        steps: [
            "Premi Nuovo decongelamento.",
            "Scegli Tracciabilità (lotto ricevuto), Alimenti in ingresso (template) o inserimento Manuale.",
            "Seleziona il metodo e avvia: il timer parte alla conferma.",
            "Al termine registra temperatura finale e eventuale azione correttiva."
        ],
        notes: [
            "Collegare un lotto tracciato migliora l'audit HACCP.",
            "Gli alimenti in ingresso si gestiscono dal menu Alimenti in ingresso.",
            "I processi attivi compaiono nell'overlay cucina."
        ]
    )

    static let oilControl = ModuleHelp(
        id: "oil",
        title: "Controllo olio",
        purpose: "Monitoraggio polarità e sostituzione olio delle friggitrici con storico e soglie HACCP.",
        steps: [
            "Seleziona il punto olio (friggitrice) dalla griglia.",
            "Registra il test di polarità o la sostituzione olio.",
            "Verifica lo storico e i filtri per periodo e operatore.",
            "Il MASTER aggiunge o modifica i punti olio."
        ],
        notes: ["Le soglie di attenzione sono in Impostazioni → Parametri HACCP."]
    )

    static let productionLabels = ModuleHelp(
        id: "labels",
        title: "Etichette di produzione",
        purpose: "Consulta, stampa e archivia etichette HACCP create dai lotti in Tracciabilità.",
        steps: [
            "Apri Tracciabilità e seleziona un prodotto ricevuto.",
            "Dalla scheda dettaglio scegli Crea etichetta e compila i dati.",
            "Stampa tramite stampante configurata in Impostazioni.",
            "Da qui puoi ritrovare, ristampare o archiviare le etichette già create."
        ],
        notes: [
            "Le nuove etichette si creano solo da Tracciabilità.",
            "Configura la stampante CLABEL da Impostazioni → Stampanti."
        ]
    )

    static let goodsReceiving = ModuleHelp(
        id: "receiving",
        title: "Ricezione merci",
        purpose: "Registrazione in ingresso di materie prime: fornitore, temperatura, lotti e conformità alla consegna.",
        steps: [
            "Seleziona il fornitore (il MASTER gestisce l'anagrafica).",
            "Scegli il prodotto e compila checklist e temperatura di arrivo.",
            "Al termine la scheda viene creata in Tracciabilità.",
            "Allega foto se richiesta per non conformità."
        ],
        notes: [
            "È il punto di partenza corretto per la tracciabilità HACCP.",
            "Nuovi fornitori richiedono PIN MASTER per l'operatore."
        ]
    )

    static let checklist = ModuleHelp(
        id: "checklist",
        title: "Checklist",
        purpose: "Controlli periodici personalizzati (apertura, chiusura, audit) con esecuzione guidata e storico.",
        steps: [
            "Dalla dashboard avvia una checklist programmata o in scadenza.",
            "Compila ogni voce con esito conforme / non conforme e note.",
            "Il MASTER crea e modifica i modelli checklist.",
            "Consulta storico e avvisi per criticità aperte."
        ],
        notes: ["Le attività rapide servono per controlli una tantum."]
    )

    static let history = ModuleHelp(
        id: "history",
        title: "Storia",
        purpose: "Archivio unificato di tutte le registrazioni HACCP del ristorante, raggruppate per modulo.",
        steps: [
            "Cerca per testo o filtra i moduli con attività.",
            "Apri un modulo per vedere il dettaglio cronologico.",
            "Usa le card riepilogative per capire volumi e criticità.",
            "Ideale per verifiche interne e ispezioni."
        ],
        notes: ["Non sostituisce i PDF ufficiali in Documenti."]
    )

    static let documents = ModuleHelp(
        id: "documents",
        title: "Documenti",
        purpose: "Archivio PDF mensili HACCP organizzato per ristorante, con registri Singoli e Combinati.",
        steps: [
            "Naviga nelle cartelle Mensili → Singoli o Combinati.",
            "Apri o condividi i PDF generati a fine mese.",
            "Il MASTER può rigenerare o eliminare documenti.",
            "Verifica lo stato di sincronizzazione iCloud se attivo."
        ],
        notes: [
            "I PDF si generano automaticamente a chiusura mese.",
            "Export e rigenerazione possono richiedere PIN MASTER."
        ]
    )

    static let analytics = ModuleHelp(
        id: "analytics",
        title: "Grafici",
        purpose: "Andamento statistico delle registrazioni HACCP per periodo: trend, conformità e volumi per modulo.",
        steps: [
            "Seleziona il periodo (settimana, mese, trimestre).",
            "Scorri le sezioni per modulo (temperature, pulizie, olio, …).",
            "Usa i grafici per riunioni HACCP e miglioramento continuo.",
            "Confronta periodi per individuare ricorrenze."
        ],
        notes: ["I dati si basano sulle registrazioni effettuate in app."]
    )

    static let alerts = ModuleHelp(
        id: "alerts",
        title: "Avvisi",
        purpose: "Centro unificato delle criticità aperte: temperature, pulizie, olio, decongelamento e checklist.",
        steps: [
            "Controlla gli avvisi attivi ordinati per gravità.",
            "Tocca Risolvi dopo aver applicato l'azione correttiva in cucina.",
            "Usa Vai al modulo per aprire la schermata di origine.",
            "Ricontrolla periodicamente che non restino avvisi aperti."
        ],
        notes: ["Risolvere un avviso non cancella il record storico del controllo."]
    )

    static let users = ModuleHelp(
        id: "users",
        title: "Utenti",
        purpose: "Gestione collaboratori, ruoli e PIN. Solo il responsabile MASTER accede a questa sezione.",
        steps: [
            "Crea utenti con ruolo adeguato (operatore, cucina, sala, …).",
            "Assegna PIN personali e verifica i permessi per modulo.",
            "Disattiva o modifica profili quando cambia il personale.",
            "Il MASTER ha accesso completo senza limitazioni."
        ],
        notes: ["La distinzione ruoli è documentata nei permessi operatore HACCP."]
    )

    static let settings = ModuleHelp(
        id: "settings",
        title: "Impostazioni",
        purpose: "Configurazione dell'app, del ristorante, dei parametri HACCP e delle integrazioni (stampante, backup).",
        steps: [
            "Profilo e Aspetto sono liberamente accessibili.",
            "Le sezioni con lucchetto richiedono PIN MASTER per l'operatore.",
            "Configura temperature, stampante e dati ristorante prima del go-live.",
            "Usa Catalogo piatti per il menu operativo."
        ],
        notes: ["Dopo modifiche importanti, verifica che tutti i moduli riflettano i nuovi parametri."]
    )

    // MARK: - Impostazioni (dettaglio)

    static let settingsProfile = ModuleHelp(
        id: "settings-profile",
        title: "Profilo utente",
        purpose: "Dati personali e PIN dell'utente collegato.",
        steps: ["Aggiorna nome e contatti.", "Cambia il PIN personale con una sequenza sicura."],
        notes: ["Ogni collaboratore deve usare il proprio account."]
    )

    static let settingsAppearance = ModuleHelp(
        id: "settings-appearance",
        title: "Aspetto",
        purpose: "Tema visivo, layout sidebar e modalità adatta alla cucina.",
        steps: ["Scegli tema chiaro o scuro.", "Imposta stile sidebar e dimensioni comode per tablet."],
        notes: []
    )

    static let settingsSecurity = ModuleHelp(
        id: "settings-security",
        title: "Sicurezza",
        purpose: "Protezione accesso app: timeout sessione e biometria.",
        steps: ["Configura auto-logout per inattività.", "Abilita Face ID / Touch ID se supportato."],
        notes: ["Riservato al MASTER."]
    )

    static let settingsRestaurant = ModuleHelp(
        id: "settings-restaurant",
        title: "Ristorante",
        purpose: "Anagrafica locale, logo e dati per etichette e documenti.",
        steps: ["Inserisci ragione sociale e indirizzo.", "Carica il logo per report ed etichette."],
        notes: ["Riservato al MASTER."]
    )

    static let settingsHACCP = ModuleHelp(
        id: "settings-haccp",
        title: "Parametri HACCP",
        purpose: "Soglie temperature, scadenze e limiti olio usati dai moduli operativi.",
        steps: [
            "Imposta range frigo, freezer e abbattimento.",
            "Definisci soglie polarità olio e giorni pre-scadenza.",
            "Salva e verifica un controllo in ogni modulo interessato."
        ],
        notes: ["Riservato al MASTER."]
    )

    static let settingsNotifications = ModuleHelp(
        id: "settings-notifications",
        title: "Notifiche",
        purpose: "Promemoria checklist e avvisi operativi.",
        steps: ["Attiva o disattiva le notifiche per tipo.", "Verifica i permessi di sistema se non arrivano alert."],
        notes: []
    )

    static let settingsData = ModuleHelp(
        id: "settings-data",
        title: "Dati e backup",
        purpose: "Spazio occupato, export e reset dell'applicazione.",
        steps: [
            "Monitora l'uso memoria locale.",
            "Esegui backup prima di reset o cambio dispositivo.",
            "Il reset cancella tutti i dati: usare solo se necessario."
        ],
        notes: ["Operazione critica: solo MASTER."]
    )

    static let settingsPrinter = ModuleHelp(
        id: "settings-printer",
        title: "Stampanti",
        purpose: "Configurazione stampante etichette CLABEL.",
        steps: ["Accoppia la stampante Bluetooth.", "Esegui stampa di prova da Etichette di produzione."],
        notes: ["Riservato al MASTER."]
    )

    static let settingsInfo = ModuleHelp(
        id: "settings-info",
        title: "Info app",
        purpose: "Versione software, note legali e documentazione.",
        steps: ["Consulta versione e build.", "Leggi termini e informativa privacy."],
        notes: []
    )
}

// MARK: - UI

struct ModuleHelpButton: View {
    let help: ModuleHelp
    var size: CGFloat = 36

    @Environment(\.theme) private var theme
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(theme.colorPrimary)
                .frame(width: size, height: size)
                .background(theme.colorPrimary.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Guida: \(help.title)")
        .sheet(isPresented: $showSheet) {
            ModuleHelpSheet(help: help)
        }
    }
}

struct ModuleHelpSheet: View {
    let help: ModuleHelp

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionSpacing) {
                    helpSection(title: "A cosa serve", icon: "lightbulb.fill") {
                        Text(help.purpose)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colorTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    helpSection(title: "Come usarlo", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(help.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(theme.typography.caption.weight(.bold))
                                        .foregroundStyle(theme.colorTextOnPrimary)
                                        .frame(width: 24, height: 24)
                                        .background(theme.colorPrimary)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(theme.typography.subheadline)
                                        .foregroundStyle(theme.colorTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    if !help.notes.isEmpty {
                        helpSection(title: "Note importanti", icon: "exclamationmark.circle.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(help.notes, id: \.self) { note in
                                    Label(note, systemImage: "checkmark.seal")
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colorTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(theme.spacing.screenPadding + 8)
            }
            .background(theme.colorBackground.ignoresSafeArea())
            .navigationTitle(help.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func helpSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colorTextPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .fill(theme.colorSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerMedium, style: .continuous)
                .stroke(theme.colorDivider.opacity(0.6), lineWidth: 1)
        )
    }
}

extension View {
    @ViewBuilder
    func moduleHelpToolbar(_ help: ModuleHelp?) -> some View {
        if let help {
            toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ModuleHelpButton(help: help)
                }
            }
        } else {
            self
        }
    }
}
