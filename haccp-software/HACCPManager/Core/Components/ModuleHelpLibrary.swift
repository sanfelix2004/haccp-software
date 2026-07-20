//
//  ModuleHelpLibrary.swift
//  Guide contestuali per moduli e sezioni HACCP (allineate allo stato attuale dell'app).
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
        purpose: """
        È la home operativa del ristorante attivo. Da qui vedi in un colpo d’occhio lo stato HACCP del giorno (urgenza, scadenze, controlli aperti) e raggiungi rapidamente ogni modulo dalla griglia o dalla sidebar.

        La dashboard non sostituisce i registri: serve a orientarsi e a partire dal lavoro più urgente. I conteggi e i badge si aggiornano dopo le registrazioni fatte negli altri moduli.
        """,
        steps: [
            "Controlla le card in alto: indicano attività urgenti, scadenze vicine e registrazioni di oggi.",
            "Apri un modulo dalla griglia (o dalla sidebar) per lavorare: tracciabilità, temperature, pulizie, etichette, checklist, ecc.",
            "Nella sezione Alimenti del menu trovi Catalogo piatti e Alimenti in ingresso (materie prime).",
            "In Sistema trovi Documenti PDF, Grafici, Storia, Avvisi, Utenti e Impostazioni.",
            "Se lavori su più locali, assicurati che in alto sia selezionato il ristorante corretto: ogni dato è separato per locale."
        ],
        notes: [
            "I badge numerici segnalano elementi da completare o da verificare, non errori di sistema.",
            "Dopo un’azione importante (es. completare pulizie o checklist), torna qui per vedere i conteggi aggiornati."
        ]
    )

    static let traceability = ModuleHelp(
        id: "traceability",
        title: "Tracciabilità",
        purpose: """
        È l’hub dei lotti in cucina: archivio di ciò che è entrato e può essere usato nelle preparazioni, con lettura etichetta via fotocamera (OCR/AI) per lotto e scadenza.

        Qui associ i lotti ai piatti, segnali non conformità e prepari il terreno per etichette di produzione e controllo scadenze. È indipendente da Ricezione merci (che registra solo l’ingresso fornitore).
        """,
        steps: [
            "Nell’archivio consulta i lotti attivi e filtra (da associare, non conformi, registrati oggi, ecc.).",
            "Tocca «Inizia sessione lotti» / scatta: fotografa l’etichetta; l’app propone codice lotto e scadenza (puoi correggere a mano se la lettura è incerta).",
            "Seleziona l’alimento in ingresso dal catalogo e, se richiesto, il fornitore; conferma per salvare il lotto.",
            "Associa i lotti ai piatti dall’archivio (azione rapida) o a fine sessione camera: serve per preparazioni e scadenze interne.",
            "Apri il dettaglio di un lotto per vedere foto, date, stato e azioni (etichetta, ritiro, non conformità).",
            "Se interrompi una sessione camera, riprendila dal banner in archivio senza perdere gli scatti già fatti."
        ],
        notes: [
            "La lettura AI può segnalare «incerta»: controlla sempre lotto e scadenza sull’etichetta fisica prima di confermare.",
            "Le scadenze operative (FEFO) si gestiscono anche in Controllo scadenze.",
            "Dopo l’associazione ai piatti, per etichettare il prodotto finito vai in Etichette di produzione."
        ]
    )

    static let fridges = ModuleHelp(
        id: "fridges",
        title: "Frigoriferi",
        purpose: """
        Modulo per il monitoraggio delle temperature di frigoriferi, freezer e dispositivi collegati. Ogni rilevazione resta nello storico HACCP; i valori fuori soglia richiedono azione correttiva e possono generare avvisi.
        """,
        steps: [
            "Seleziona il dispositivo (frigo/freezer) dalla lista o griglia.",
            "Registra la temperatura rilevata al momento del controllo.",
            "Se il valore è fuori dal range impostato in Parametri HACCP, inserisci l’azione correttiva obbligatoria e conferma.",
            "Consulta lo storico del dispositivo per audit e confronti nel tempo.",
            "Il MASTER configura dispositivi, soglie e anagrafica da questa area (o da Impostazioni / parametri collegati)."
        ],
        notes: [
            "Gli avvisi temperatura compaiono anche nel centro Avvisi.",
            "Usa sempre lo stesso dispositivo corretto: lo storico è per attrezzatura, non generico."
        ]
    )

    static let cleaningControl = ModuleHelp(
        id: "cleaning",
        title: "Controllo pulizia",
        purpose: """
        Piano di sanificazione per aree (Cucina, Area rifiuti, …) e attività periodiche. In alto vedi il completamento del periodo corrente con un indicatore circolare (percentuale e conteggio task).

        Il tab Attività mostra le macro-aree espandibili con i controlli del filtro (Oggi / In ritardo / Completate). Il tab Storico conserva le evidenze già chiuse. La gestione aree/task e la pulizia storico sono riservate ai profili autorizzati (spesso MASTER).
        """,
        steps: [
            "Guarda l’anello di progresso: indica quanti task del ciclo corrente sono già fatti.",
            "Nel tab Attività scegli Oggi, In ritardo o Completate con i segmenti sotto i pulsanti di gestione.",
            "Apri una card area (chevron) per vedere i singoli controlli; tocca il cerchio a destra di una riga per segnarla completata.",
            "Usa «Completa Tutti» sulla card area (senza entrare nel dettaglio) per chiudere in un colpo tutti i task aperti di quell’area; conferma nella finestra di dialogo.",
            "«Gestione aree/task» (icona ingranaggio): crea/elimina aree e attività con frequenza (giornaliero, settimanale, …).",
            "«Pulisci storico» (icona cestino): cancella lo storico secondo i permessi; richiede autorizzazione elevata.",
            "Nel tab Storico rivedi i controlli già registrati per audit."
        ],
        notes: [
            "Se un’area mostra «Nessun dato», in quel filtro non ci sono controlli da fare: non è un errore di sistema.",
            "Completare tutto segna come fatti solo i task aperti dell’area nel filtro corrente.",
            "Le attività di pulizia possono essere collegate anche alle checklist di sistema (ponte): restano coerenti tra i moduli."
        ]
    )

    static let blastChilling = ModuleHelp(
        id: "blast",
        title: "Abbattimento",
        purpose: """
        Registro del ciclo di abbattimento (raffreddamento rapido / surgelazione controllata): temperatura iniziale, tempi, temperatura finale, esito e operatore. Al termine puoi creare subito l’etichetta HACCP (formato 50×30 mm) con i dati essenziali (Abb., Scad, Ti/Tf, Dur.) e QR.
        """,
        steps: [
            "Premi Nuovo abbattimento e scegli il piatto dal Catalogo piatti.",
            "Inserisci la temperatura iniziale e avvia il processo / timer.",
            "Al termine registra temperatura finale, note ed eventuali azioni correttive, poi conferma con firma/operatore.",
            "Se proposto, crea e stampa l’etichetta: sull’adesivo compaiono nome, data abbattimento (Abb.), scadenza, temperature iniziale/finale, durata e QR.",
            "Gli abbattimenti in corso restano visibili (overlay / elenco attivi) finché non li chiudi.",
            "Ritrovi le etichette anche in Etichette di produzione → Abbattimento."
        ],
        notes: [
            "Un solo abbattimento in corso per lo stesso piatto.",
            "Il catalogo piatti si gestisce da Alimenti → Catalogo piatti.",
            "La scansione del QR etichetta funziona dall’app su iPad."
        ]
    )

    static let productionCatalog = ModuleHelp(
        id: "catalog",
        title: "Catalogo piatti",
        purpose: """
        Elenco centralizzato delle preparazioni/piatti del menu (es. Barbabietola, Baccalà) usato da Abbattimento, Tracciabilità (associazione lotti) e Etichette. Non contiene le materie prime in ingresso (quelle stanno in Alimenti in ingresso).
        """,
        steps: [
            "Filtra per categoria con i tab in alto.",
            "Tocca un piatto per selezionarlo; poi Modifica o Elimina (se permesso).",
            "Usa Aggiungi piatto per creare una voce con nome, categoria e dati utili alla scadenza interna.",
            "Le modifiche sono subito disponibili in Abbattimento e negli altri moduli collegati."
        ],
        notes: [
            "Aggiunta/modifica/eliminazione possono richiedere PIN MASTER.",
            "Un piatto già usato nello storico abbattimento non si elimina finché resta referenziato.",
            "Per etichettare un piatto dopo abbattimento: Etichette → Abbattimento (o stampa a fine ciclo)."
        ]
    )

    static let incomingFoodCatalog = ModuleHelp(
        id: "incoming-food",
        title: "Alimenti in ingresso",
        purpose: """
        Catalogo delle materie prime / prodotti in ingresso (surgelati, freschi, scatolame, …) usato in Ricezione merci, Tracciabilità e Decongelamento. È distinto dal Catalogo piatti.
        """,
        steps: [
            "Filtra per categoria merce con i tab.",
            "Tocca un alimento per selezionarlo; Modifica o Elimina secondo i permessi.",
            "Aggiungi alimento per creare un nuovo tipo usato in ricezione e decongelamento.",
            "In Tracciabilità, quando fotografi un’etichetta, scegli l’alimento di questo catalogo."
        ],
        notes: [
            "Non confondere con i piatti del menu.",
            "Un alimento già usato in ricezioni o decongelamenti non può essere eliminato liberamente.",
            "Per etichettare un lotto dopo uso in cucina: Etichette → percorso Tracciabilità / produzione collegata."
        ]
    )

    static let expiryControl = ModuleHelp(
        id: "expiry",
        title: "Controllo scadenze e quantità",
        purpose: """
        Due aree chiare: Alimenti in ingresso (lotti da associare o già associati) e Produzioni (piatti preparati). Controlli la scadenza, chiudi i scaduti e termini/scarti con motivazione.
        """,
        steps: [
            "Tocca la box Alimenti in ingresso oppure Produzioni.",
            "Nella sezione «Da chiudere» tocca un scaduto e registra Usato o Scartato (motivazione obbligatoria sullo scarto).",
            "Nella sezione «In validità / Da tenere» tocca un lotto per Termina / Scarta con motivazione.",
            "I filtri in alto aiutano a vedere solo scaduti o in scadenza.",
            "Nascondere una voce dalla Storia (MASTER) è un’operazione separata: qui gestisci solo lo stock operativo."
        ],
        notes: [
            "La soglia «in scadenza» si regola in Impostazioni → Parametri HACCP.",
            "Le chiusure (terminato / scaduto / scartato) restano nei Documenti (PDF Tracciabilità e produzioni).",
            "Per dettagli completi del lotto usa Tracciabilità."
        ]
    )

    static let defrost = ModuleHelp(
        id: "defrost",
        title: "Decongelamento",
        purpose: """
        Traccia i cicli di decongelamento: prodotto, lotto, metodo, orari, temperatura iniziale e finale, durata e conformità. Al completamento puoi stampare l’etichetta 50×30 con Dec., Scad (di solito entro 24h), Ti/Tf, Dur. e QR.
        """,
        steps: [
            "Premi Nuovo decongelamento.",
            "Scegli la fonte: lotto da Tracciabilità, template Alimenti in ingresso, o inserimento manuale.",
            "Seleziona il metodo, inserisci la temperatura iniziale e avvia: il timer / stato attivo parte alla conferma.",
            "Al termine registra temperatura finale, esito e eventuali azioni correttive.",
            "Crea/stampa l’etichetta se proposto: sull’adesivo compaiono Ti, Tf e durata del decongelamento.",
            "I processi attivi compaiono nell’overlay cucina finché non chiusi."
        ],
        notes: [
            "Collegare un lotto tracciato migliora l’audit.",
            "Le etichette si ritrovano in Etichette → Decongelamento.",
            "Scansione QR dall’app su iPad."
        ]
    )

    static let oilControl = ModuleHelp(
        id: "oil",
        title: "Controllo olio",
        purpose: """
        Monitoraggio della qualità olio delle friggitrici (polarità / test) e delle sostituzioni, con storico per punto olio e soglie definite nei parametri HACCP.
        """,
        steps: [
            "Seleziona il punto olio (friggitrice) dalla griglia.",
            "Registra un test di polarità o una sostituzione olio con data/operatore.",
            "Se il valore supera la soglia, segui l’azione richiesta (cambio olio, nota, avviso).",
            "Consulta lo storico filtrando per periodo e operatore.",
            "Il MASTER aggiunge o modifica i punti olio."
        ],
        notes: [
            "Le soglie di attenzione sono in Impostazioni → Parametri HACCP.",
            "Gli avvisi olio possono comparire anche in Avvisi."
        ]
    )

    static let productionLabels = ModuleHelp(
        id: "labels",
        title: "Etichette di produzione",
        purpose: """
        Crea, stampa e archivia etichette HACCP per prodotti già lavorati in cucina (produzione, abbattimento, decongelamento). Rotolo supportato: 50×30 mm (CLABEL). Il layout stampa solo i campi essenziali a sinistra e un QR a destra (non a filo bordo).

        Layout tipici:
        • Produzione: nome, Scad, Prod, Lotto, Op.
        • Abbattimento: nome, Abb., Scad, Ti/Tf, Dur.
        • Decongelamento: nome, Dec., Scad, Ti/Tf, Dur.

        La scansione del QR per riaprire la scheda avviene dall’app su iPad (non è pensata come flusso telefono).
        """,
        steps: [
            "Nella home del modulo vedi conteggi del giorno e i tipi di etichetta (Produzione / Abbattimento / Decongelamento).",
            "Apri un tipo, scegli il record/processo da etichettare e genera l’etichetta.",
            "Controlla l’anteprima: testo compatto + QR; poi Salva e stampa sulla CLABEL collegata.",
            "Se la stampante non è pronta, il job resta in coda e si stampa appena connessa.",
            "Usa «Scansiona QR etichetta» (solo iPad) per rileggere un’etichetta già stampata e aprirne la scheda.",
            "Da ogni etichetta puoi ristampare o archiviare; un elemento HACCP non deve avere duplicati inutili: preferisci ristampa."
        ],
        notes: [
            "Le materie prime in ingresso hanno già l’etichetta fornitore: non vanno ristampate qui.",
            "Configura Bluetooth e layout in Impostazioni → Stampanti (formato 50×30).",
            "Caratteri speciali (°, ellissi tipografiche) vengono semplificati in stampa per evitare simboli strani sulla termica.",
            "Operatore sull’etichetta: di solito chi ha eseguito il processo (abbattimento/decongelamento)."
        ]
    )

    static let goodsReceiving = ModuleHelp(
        id: "receiving",
        title: "Ricezione merci",
        purpose: """
        Registro dell’ingresso merce dal fornitore: chi consegna, cosa arriva, conformità. Non sostituisce la Tracciabilità lotti (foto etichetta lotto/scadenza in cucina). Foto e dettagli extra servono soprattutto in caso di anomalia.
        """,
        steps: [
            "Seleziona o conferma il fornitore (anagrafica gestita dal MASTER).",
            "Scegli l’alimento in ingresso dal catalogo e registra la ricezione.",
            "Se conforme, salva con i dati minimi richiesti.",
            "Se non conforme: descrivi il problema, allega foto se serve, indica scarto o reso al fornitore.",
            "Consulta lo storico ricezioni per controlli e fornitori ricorrenti."
        ],
        notes: [
            "Modulo indipendente dalla Tracciabilità lotti in produzione.",
            "Nuovi fornitori o modifiche anagrafiche possono richiedere PIN MASTER.",
            "Per usare il lotto in cucina, registra anche in Tracciabilità con foto etichetta."
        ]
    )

    static let checklist = ModuleHelp(
        id: "checklist",
        title: "Checklist",
        purpose: """
        Controlli HACCP strutturati per modelli e frequenza (giornalieri, settimanali, mensili, annuali). I tab principali sono Modelli, Oggi, Storico e Criticità.

        «Oggi» mostra ciò che va fatto nel giorno corrente (aperure/chiusure e periodici in scadenza). «Modelli» serve a creare e modificare le checklist. «Storico» e «Criticità» servono ad audit e NON conformità.
        """,
        steps: [
            "Tab Oggi: apri una checklist in scadenza e completa le voci (OK / KO / N/A secondo il modello).",
            "Su checklist lunghe, se previsto usa azioni rapide tipo «tutto conforme» e correggi solo le eccezioni.",
            "In caso di KO registra nota / azione correttiva come richiesto dalla voce.",
            "Tab Modelli: il responsabile crea o modifica frequenza, giorno previsto e elenco voci.",
            "Tab Storico: rivedi esecuzioni passate; Criticità: gestisci le non conformità aperte.",
            "Puoi avviare o riprendere run anche dallo storico se l’app lo consente per quel modello."
        ],
        notes: [
            "Settimanali tipicamente concentrati (es. lunedì); mensili/annuali solo nei giorni previsti.",
            "Le attività di pulizia possono essere collegate anche al modulo Controllo pulizia.",
            "Le criticità risolte restano tracciate nello storico."
        ]
    )

    static let history = ModuleHelp(
        id: "history",
        title: "Storia",
        purpose: """
        Archivio unificato delle registrazioni HACCP del ristorante, raggruppate per modulo e data. Serve a ispezioni e verifiche interne senza aprire ogni modulo uno per uno. Non sostituisce i PDF ufficiali in Documenti.
        """,
        steps: [
            "Dalla dashboard Storia vedi i moduli con attività e volumi.",
            "Cerca per testo o filtra i moduli attivi.",
            "Apri un modulo per lo storico cronologico dettagliato (operatore, esito, note).",
            "Le produzioni collegate mostrano nomi leggibili (piatti), non solo ID interni.",
            "Usa le card riepilogative per capire criticità e carichi di lavoro."
        ],
        notes: [
            "Per documenti formali mensili vai in Documenti / iCloud.",
            "Chiusure lotti: restano nei Documenti (PDF Tracciabilità e produzioni); in Storia vedi solo i lotti ancora da chiudere.",
            "Ogni voce conserva data, operatore e dettaglio dell’azione."
        ]
    )

    static let documents = ModuleHelp(
        id: "documents",
        title: "Documenti",
        purpose: """
        Archivio dei PDF mensili HACCP generati dall’app, con possibilità di backup su iCloud Drive. È il deposito «ufficiale» periodico, complementare allo Storico operativo.
        """,
        steps: [
            "Naviga nelle cartelle Mensili e scegli il modulo (temperature, pulizie, …).",
            "Apri o condividi i PDF già generati.",
            "Usa la card Backup iCloud per sincronizzare o forzare una copia.",
            "Il MASTER può rigenerare o eliminare documenti secondo procedura."
        ],
        notes: [
            "I PDF tipicamente si generano a chiusura mese e possono copiarsi su iCloud.",
            "Export e rigenerazione possono richiedere PIN MASTER.",
            "Configura email/account backup in Impostazioni → Dati e backup."
        ]
    )

    static let analytics = ModuleHelp(
        id: "analytics",
        title: "Grafici",
        purpose: """
        Vista analitica sulle registrazioni HACCP: trend, volumi e conformità per periodo. Utile per riunioni periodiche e miglioramento continuo, non per il lavoro minuto per minuto in cucina.
        """,
        steps: [
            "Seleziona il periodo (settimana, mese, trimestre, …).",
            "Scorri le sezioni per modulo (temperature, pulizie, olio, abbattimenti, …).",
            "Confronta periodi per individuare ricorrenze o picchi di non conformità.",
            "Usa i KPI/card come supporto alle decisioni, poi approfondisci nello Storico o nel modulo specifico."
        ],
        notes: [
            "I grafici si basano solo sulle registrazioni effettuate in app.",
            "Se un grafico è vuoto, manca storico nel periodo scelto."
        ]
    )

    static let alerts = ModuleHelp(
        id: "alerts",
        title: "Avvisi",
        purpose: """
        Centro unificato delle criticità aperte provenienti da temperature, pulizie, olio, decongelamento, checklist e altri moduli. Qui chiudi il cerchio operativo dopo aver agito in cucina.
        """,
        steps: [
            "Elenca gli avvisi attivi ordinati per gravità / urgenza.",
            "Tocca un avviso per capire origine e dettaglio.",
            "Usa «Vai al modulo» per correggere nel contesto giusto (es. rifare temperatura, completare pulizia).",
            "Quando l’azione correttiva è fatta, marca Risolvi / chiudi l’avviso.",
            "Ricontrolla periodicamente che non restino avvisi aperti."
        ],
        notes: [
            "Risolvere un avviso non cancella il record storico del controllo.",
            "Se riappare subito, verifica soglie HACCP e procedura sul campo."
        ]
    )

    static let users = ModuleHelp(
        id: "users",
        title: "Utenti",
        purpose: """
        Anagrafica collaboratori, ruoli e PIN. Solo il MASTER (o profili equivalenti) gestisce questa sezione. I permessi decidono chi esegue controlli, chi configura aree/stampante, chi cancella storici.
        """,
        steps: [
            "Crea utenti con ruolo adeguato (operatore, cucina, sala, responsabile, …).",
            "Assegna PIN personali e verifica i permessi per modulo.",
            "Disattiva o aggiorna profili quando cambia il personale.",
            "Fai accedere ogni persona con il proprio account: l’operatore resta stampato su registri ed etichette."
        ],
        notes: [
            "Il MASTER ha accesso completo; gli operatori vedono solo ciò che i permessi consentono.",
            "Non condividere il PIN MASTER in cucina."
        ]
    )

    static let settings = ModuleHelp(
        id: "settings",
        title: "Impostazioni",
        purpose: """
        Configurazione dell’app e del ristorante: profilo, aspetto, sicurezza, anagrafica locale, parametri HACCP, notifiche, backup, stampante etichette e info versione. Profilo e Aspetto sono di solito liberamente accessibili; molte altre sezioni richiedono PIN MASTER.
        """,
        steps: [
            "Apri la voce che ti serve (Profilo, Aspetto, HACCP, Stampanti, …).",
            "Se compare il lucchetto, autentica come MASTER e procedi.",
            "Dopo aver cambiato soglie o stampante, fai una prova operativa nel modulo interessato.",
            "Catalogo piatti e Alimenti in ingresso restano nel menu laterale Alimenti, non necessariamente qui."
        ],
        notes: [
            "Ogni ristorante ha le proprie impostazioni: controlla il locale attivo.",
            "Le guide dettagliate di ogni sottosezione si aprono dal pulsante Info dentro la sezione."
        ]
    )

    // MARK: - Impostazioni (dettaglio)

    static let settingsProfile = ModuleHelp(
        id: "settings-profile",
        title: "Profilo utente",
        purpose: """
        Dati dell’utente attualmente collegato: nome visualizzato, contatti e PIN personale. Il nome compare su registrazioni, etichette (quando non c’è operatore di processo) e storico.
        """,
        steps: [
            "Verifica nome e dati mostrati in cucina / sui report.",
            "Aggiorna contatti se usati per comunicazioni o backup.",
            "Cambia il PIN personale scegliendo una sequenza non ovvia e non condivisa."
        ],
        notes: [
            "Ogni collaboratore deve usare il proprio account: altrimenti lo storico attribuisce azioni alla persona sbagliata."
        ]
    )

    static let settingsAppearance = ModuleHelp(
        id: "settings-appearance",
        title: "Aspetto",
        purpose: """
        Tema visivo (chiaro/scuro), stile sidebar e comfort di lettura su iPad in cucina. Non cambia i dati HACCP, solo come li vedi.
        """,
        steps: [
            "Scegli tema chiaro o scuro in base all’illuminazione del locale.",
            "Regola layout sidebar / dimensioni se disponibili.",
            "Verifica su iPad che testi e bottoni restino comodi da toccare con i guanti o in fretta."
        ],
        notes: [
            "Le preferenze aspetto possono sincronizzarsi sul dispositivo; non sostituiscono i parametri HACCP."
        ]
    )

    static let settingsSecurity = ModuleHelp(
        id: "settings-security",
        title: "Sicurezza",
        purpose: """
        Protezione dell’accesso all’app: timeout di sessione, blocco e biometria (Face ID / Touch ID) dove supportati. Riduce il rischio che un tablet lasciato in cucina resti aperto con privilegi elevati.
        """,
        steps: [
            "Imposta l’auto-logout dopo inattività adeguata al flusso di lavoro.",
            "Abilita Face ID / Touch ID se il dispositivo lo supporta e la policy interna lo richiede.",
            "Verifica che dopo il blocco serva PIN/biometria per rientrare."
        ],
        notes: [
            "Di solito riservato al MASTER.",
            "Timeout troppo lunghi aumentano il rischio; troppo corti rallentano il servizio: trova il compromesso."
        ]
    )

    static let settingsRestaurant = ModuleHelp(
        id: "settings-restaurant",
        title: "Ristorante",
        purpose: """
        Anagrafica del locale attivo: ragione sociale, indirizzo, logo e dati usati su etichette, documenti e intestazioni. Ogni ristorante in app ha la propria anagrafica.
        """,
        steps: [
            "Inserisci o aggiorna ragione sociale e indirizzo.",
            "Carica il logo se usato su report/etichette.",
            "Salva e controlla un’anteprima etichetta o un PDF per verificare i dati stampati."
        ],
        notes: [
            "Riservato al MASTER.",
            "Se hai più locali, seleziona quello giusto prima di modificare."
        ]
    )

    static let settingsHACCP = ModuleHelp(
        id: "settings-haccp",
        title: "Parametri HACCP",
        purpose: """
        Soglie e regole usate dai moduli operativi: temperature (frigo/freezer/abbattimento), polarità olio, giorni «in scadenza», opzioni OCR/tracciabilità e altri limiti. Cambiare qui influenza controlli, colori e avvisi in tutta l’app.
        """,
        steps: [
            "Imposta i range temperatura coerenti con il piano HACCP interno.",
            "Definisci soglie olio e giorni di pre-avviso scadenze.",
            "Se presenti, configura opzioni lettura lotto / obbligatorietà campi.",
            "Salva e fai una prova in Frigoriferi, Controllo scadenze e Controllo olio."
        ],
        notes: [
            "Riservato al MASTER.",
            "Valori troppo stretti generano molti avvisi; troppo larghi riducono la tutela: allinea al manuale aziendale."
        ]
    )

    static let settingsNotifications = ModuleHelp(
        id: "settings-notifications",
        title: "Notifiche",
        purpose: """
        Promemoria e alert di sistema legati a checklist, scadenze, backup e altre scadenze operative. Dipendono anche dai permessi di notifica iPad/iOS.
        """,
        steps: [
            "Attiva o disattiva le categorie di notifica che ti servono.",
            "Se non ricevi alert, verifica Impostazioni iPad → Notifiche → HACCP Manager.",
            "Il backup iCloud può notificare l’esito della sincronizzazione mensile."
        ],
        notes: [
            "Le notifiche non sostituiscono il controllo a inizio turno in Dashboard / Avvisi."
        ]
    )

    static let settingsData = ModuleHelp(
        id: "settings-data",
        title: "Dati e backup",
        purpose: """
        Spazio dati, backup mensile su iCloud Drive (PDF/documenti) e operazioni critiche come reset. Protegge l’archivio HACCP oltre lo storico in-app.
        """,
        steps: [
            "Inserisci l’email/account di riferimento (spesso iCloud).",
            "Attiva il backup automatico mensile se richiesto dalla procedura.",
            "Usa «Sincronizza ora» per forzare una copia manuale.",
            "Controlla su iCloud Drive la struttura Mensili → moduli.",
            "Il reset cancella i dati locali: usarlo solo con procedura scritta e backup verificato."
        ],
        notes: [
            "Operazioni critiche: solo MASTER.",
            "Il backup iCloud non sostituisce le buone pratiche di export/audit periodici."
        ]
    )

    static let settingsPrinter = ModuleHelp(
        id: "settings-printer",
        title: "Stampanti",
        purpose: """
        Configurazione della stampante termica CLABEL (Bluetooth) per etichette di produzione. Formato operativo attuale: rotolo 50×30 mm. Qui colleghi la stampante, scegli il motore di stampa e fai le prove; le etichette vere si creano nel modulo Etichette.
        """,
        steps: [
            "Accendi la stampante e assicurati che il rotolo 50×30 sia montato correttamente.",
            "Da questa schermata cerca/accoppia il dispositivo Bluetooth e attendi lo stato connesso.",
            "Esegui una stampa di prova per verificare allineamento, contrasto e QR.",
            "Regola i campi visibili (nome, date, lotto, operatore, QR) secondo le esigenze, ricordando che su 50×30 lo spazio è limitato.",
            "Torna in Etichette di produzione per stampare etichette reali; se offline, i job restano in coda."
        ],
        notes: [
            "Riservato al MASTER / profilo con gestione stampante.",
            "QR troppo grande o troppo a bordo può risultare tagliato: usa i default aggiornati e ristampa dopo le modifiche.",
            "Scansione QR etichette: solo dall’app su iPad."
        ]
    )

    static let settingsInfo = ModuleHelp(
        id: "settings-info",
        title: "Info app",
        purpose: """
        Versione software, build e documenti legali (termini, privacy). Utile per assistenza e per sapere quale versione è installata sul tablet.
        """,
        steps: [
            "Leggi versione e build correnti.",
            "Consulta termini e informativa privacy se richiesto.",
            "In caso di problema, comunica versione + dispositivo (iPad) all’assistenza."
        ],
        notes: [
            "Aggiornare l’app può cambiare layout etichette o moduli: dopo un update rileggi le guide Info dei moduli che usi di più."
        ]
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
                    helpSection(title: "A cosa serve questa scheda", icon: "lightbulb.fill") {
                        Text(help.purpose)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colorTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    helpSection(title: "Come usarla (passo passo)", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(help.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(theme.typography.caption.weight(.bold))
                                        .foregroundStyle(theme.colorTextOnPrimary)
                                        .frame(width: 26, height: 26)
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
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(help.notes.enumerated()), id: \.offset) { _, note in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.colorPrimary)
                                            .padding(.top, 2)
                                        Text(note)
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colorTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
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
