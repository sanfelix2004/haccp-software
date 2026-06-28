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
            "Gestisci cataloghi da Alimenti nel menu laterale (piatti e materie prime).",
            "Usa la sezione Sistema per documenti, grafici, storico e avvisi."
        ],
        notes: ["I badge numerici indicano elementi da completare o da verificare."]
    )

    static let traceability = ModuleHelp(
        id: "traceability",
        title: "Tracciabilità",
        purpose: "Hub lotti in cucina: archivio, associazione ai piatti e registrazione rapida via fotocamera.",
        steps: [
            "Dall'archivio consulta i lotti attivi e usa i filtri (da associare, non conformi, oggi).",
            "Tocca «Inizia sessione lotti» per registrare etichette: lettura AI lotto/scadenza, alimento in ingresso e fornitore.",
            "Associa i lotti ai piatti dall'archivio (azione rapida) o a fine sessione camera.",
            "Apri il dettaglio per etichette HACCP o segnalazione non conformità."
        ],
        notes: [
            "Indipendente da Ricezione merci.",
            "Le scadenze si gestiscono nel modulo Controllo scadenze.",
            "Una sessione camera interrotta può essere ripresa dal banner in archivio."
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
            "Al completamento puoi creare e stampare subito l'etichetta HACCP con QR.",
            "Gli abbattimenti in corso sono visibili nell'overlay in basso a destra."
        ],
        notes: [
            "Il catalogo piatti si gestisce dalla sezione Alimenti nel menu laterale.",
            "Le etichette si ritrovano anche in Etichette → Abbattimento.",
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
            "Un piatto già usato nello storico abbattimento non può essere eliminato.",
            "Per etichettare un piatto preparato usa Etichette → Abbattimento dopo l'abbattimento."
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
            "Un alimento già usato in ricezioni o decongelamenti non può essere eliminato.",
            "Per etichettare un lotto usa Etichette → Tracciabilità."
        ]
    )

    static let expiryControl = ModuleHelp(
        id: "expiry",
        title: "Controllo scadenze",
        purpose: "Due binari operativi: Dispensa & Frighi (materie prime) e Produzioni Interne (piatti preparati), con ordine FEFO e codici colore.",
        steps: [
            "Tab Dispensa: monitora ingredienti fotografati in Tracciabilità (scadenza fornitore).",
            "Tab Produzioni: monitora batch preparati (scadenza = min durata catalogo e ingrediente più vicino).",
            "Rosso = scaduto o oggi; giallo = entro 48 ore; verde = conforme.",
            "Scorri a sinistra e «Cancella» quando il prodotto è finito (resta nello storico HACCP).",
            "Tocca un lotto scaduto per registrare ritiro o scarto."
        ],
        notes: [
            "La scadenza del piatto non può superare quella dell'ingrediente più vicino, salvo forzatura in Tracciabilità (cottura).",
            "Cancellare un ingrediente non rimuove le produzioni già preparate.",
            "La soglia «in scadenza» nei filtri si imposta in Impostazioni → HACCP."
        ]
    )

    static let defrost = ModuleHelp(
        id: "defrost",
        title: "Decongelamento",
        purpose: "Tracciamento dei cicli di decongelamento con metodo, durata e temperatura finale.",
        steps: [
            "Premi Nuovo decongelamento.",
            "Scegli Tracciabilità (lotto ricevuto), Alimenti in ingresso (template) o inserimento Manuale.",
            "Seleziona il metodo e avvia: il timer parte alla conferma.",
            "Al termine registra temperatura finale e eventuale azione correttiva.",
            "Al completamento puoi creare e stampare l'etichetta HACCP con QR."
        ],
        notes: [
            "Collegare un lotto tracciato migliora l'audit HACCP.",
            "Gli alimenti in ingresso si gestiscono dalla sezione Alimenti nel menu laterale.",
            "Le etichette si ritrovano in Etichette → Decongelamento.",
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
        purpose: "Crea, stampa e archivia etichette HACCP per prodotti preparati in cucina (non per ri-etichettare le materie prime in ingresso).",
        steps: [
            "Scegli il tipo: Produzione finita, Abbattimento o Decongelamento.",
            "Seleziona il piatto preparato o il processo completato da cui generare l'etichetta.",
            "Controlla l'anteprima con dati, allergeni e QR, poi Salva e stampa.",
            "Ritrova le etichette create nella stessa sezione; scansiona il QR per riaprirle.",
            "Da ogni etichetta puoi ristampare o archiviare."
        ],
        notes: [
            "Le materie prime in ingresso hanno già l'etichetta del fornitore: non serve ristamparle.",
            "Dopo aver associato i lotti a un piatto in Tracciabilità, etichetta da Produzione finita.",
            "I piatti surgelati si etichettano anche da Abbattimento al termine del ciclo.",
            "Ogni elemento HACCP può avere una sola etichetta: per ristampare usa l'etichetta esistente.",
            "Se la stampante non è pronta, l'etichetta resta in coda e si stampa appena connessa.",
            "Configura la stampante CLABEL da Impostazioni → Stampanti."
        ]
    )

    static let goodsReceiving = ModuleHelp(
        id: "receiving",
        title: "Ricezione merci",
        purpose: "Registro ingresso merce: fornitore, alimento in ingresso e conformità. Foto solo in caso di anomalia.",
        steps: [
            "Seleziona il fornitore (il MASTER gestisce l'anagrafica).",
            "Scegli l'alimento in ingresso dal catalogo e conferma la ricezione.",
            "Se la merce è conforme, salva senza altri dati.",
            "Se c'è un problema: descrivi, scatta foto del danneggiato e indica se scartata o restituita al fornitore."
        ],
        notes: [
            "Modulo indipendente dalla Tracciabilità lotti in produzione.",
            "Nuovi fornitori richiedono PIN MASTER per l'operatore."
        ]
    )

    static let checklist = ModuleHelp(
        id: "checklist",
        title: "Checklist",
        purpose: "Controlli HACCP per frequenza: giornalieri sempre visibili, settimanali/mensili/annuali solo nel giorno previsto.",
        steps: [
            "Nel tab Oggi compaiono solo le checklist del giorno (apertura, chiusura…) e i controlli periodici in scadenza.",
            "Per controlli con molte voci (es. guarnizioni frigo) usa il pulsante «tutto conforme» e correggi solo le eccezioni.",
            "Il MASTER crea e modifica i modelli nel tab Modelli (frequenza, giorno, voci).",
            "Consulta storico e criticità per le NON conformità."
        ],
        notes: [
            "Settimanali: ideali il lunedì mattina. Mensili: 1° del mese. Annuali: scadenze documentali.",
            "Le attività rapide servono per controlli una tantum."
        ]
    )

    static let history = ModuleHelp(
        id: "history",
        title: "Storia",
        purpose: "Archivio unificato di tutte le registrazioni HACCP del ristorante, raggruppate per modulo.",
        steps: [
            "Cerca per testo o filtra i moduli con attività.",
            "Apri un modulo per vedere il registro cronologico dettagliato.",
            "Le produzioni collegate mostrano il nome del piatto, non codici interni.",
            "Usa le card riepilogative per capire volumi e criticità.",
            "Ideale per verifiche interne e ispezioni."
        ],
        notes: [
            "Non sostituisce i PDF ufficiali in Documenti.",
            "Ogni voce conserva data, operatore e dettaglio dell'azione registrata."
        ]
    )

    static let documents = ModuleHelp(
        id: "documents",
        title: "Documenti",
        purpose: "Archivio PDF mensili HACCP con backup su iCloud Drive.",
        steps: [
            "Naviga nelle cartelle Mensili e apri il modulo che ti serve.",
            "Apri o condividi i PDF generati a fine mese.",
            "Usa la card Backup iCloud per sincronizzare l'archivio.",
            "Il MASTER può rigenerare o eliminare documenti."
        ],
        notes: [
            "I PDF si generano automaticamente a chiusura mese e si copiano su iCloud.",
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
            "Catalogo piatti e Alimenti in ingresso sono nel menu laterale, sezione Alimenti."
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
        steps: ["Attiva o disattiva le notifiche per tipo.", "Il backup iCloud mensile invia un avviso al termine della sincronizzazione.", "Verifica i permessi di sistema se non arrivano alert."],
        notes: []
    )

    static let settingsData = ModuleHelp(
        id: "settings-data",
        title: "Dati e backup",
        purpose: "Spazio occupato, backup mensile su iCloud Drive e reset dell'applicazione.",
        steps: [
            "Inserisci l'email di riferimento (consigliata: account iCloud).",
            "Attiva il backup automatico mensile su iCloud.",
            "All'inizio di ogni mese i PDF vengono generati e copiati su iCloud Drive.",
            "Usa «Sincronizza ora» per forzare la copia manuale.",
            "Il reset cancella tutti i dati: usare solo se necessario."
        ],
        notes: ["Operazioni critiche: solo MASTER.", "La struttura su iCloud replica Mensili → {Modulo}."]
    )

    static let settingsPrinter = ModuleHelp(
        id: "settings-printer",
        title: "Stampanti",
        purpose: "Configurazione stampante etichette CLABEL via Bluetooth.",
        steps: [
            "Accoppia la stampante Bluetooth e attendi lo stato Connessa.",
            "Esegui una stampa di prova da questa schermata.",
            "Le etichette operative si creano e stampano dal modulo Etichette di produzione.",
            "Se il canale non è pronto, le stampe restano in coda finché la stampante non risponde."
        ],
        notes: ["Riservato al MASTER.", "Il QR sulle etichette è configurabile qui (dimensione e rotazione)."]
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
