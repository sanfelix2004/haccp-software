//
//  LegalDocumentBodies.swift
//  Testi legali e informativi (bozza professionale — revisione legale consigliata prima del rilascio).
//

import Foundation

enum LegalDocumentBodies {

    // MARK: - Termini e Condizioni

    static let terms = """
    ## 1. Oggetto

    I presenti **Termini e Condizioni d'Uso** («Termini») regolano l'accesso e l'utilizzo dell'applicazione mobile **\(LegalConstants.appName)** («App»), software gestionale per la registrazione operativa del sistema di autocontrollo igienico-sanitario (HACCP) in ambito ristorazione e attività alimentari.

    L'App è fornita da **\(LegalConstants.dataController)** («Fornitore»), con sede in \(LegalConstants.registeredOffice).

    L'installazione, l'accesso o l'uso continuato dell'App implicano l'accettazione integrale dei presenti Termini. Se non si accettano, non utilizzare l'App.

    ## 2. Destinatari e licenza d'uso

    L'App è destinata a **operatori del settore alimentare** (ristoranti, mense, laboratori, ecc.) e al loro personale autorizzato.

    Il Fornitore concede una licenza **non esclusiva, non trasferibile e revocabile** per l'uso dell'App su dispositivi Apple compatibili, esclusivamente per finalità professionali legate alla gestione HACCP del locale indicato in configurazione.

    È vietato: decompilare o modificare l'App salvo quanto consentito dalla legge; rivenderla o concederla in sublicenza; utilizzarla per scopi illeciti; aggirare misure di sicurezza; estrarre dati di terzi senza titolo.

    ## 3. Ruoli e responsabilità dell'utente MASTER

    L'utente con profilo **MASTER** è responsabile di:

    - configurazione del ristorante e dei parametri HACCP;
    - creazione, modifica e disattivazione degli account del personale;
    - correttezza e completezza dei dati inseriti dagli operatori;
    - backup periodico e conservazione dei documenti richiesti dalla normativa;
    - rispetto del Reg. (CE) n. 852/2004, del D.Lgs. 193/2007 e delle disposizioni ASL/ASL competenti applicabili al proprio esercizio.

    Gli altri profili (operatore, supervisore, ecc.) devono utilizzare l'App solo nell'ambito delle mansioni autorizzate.

    ## 4. Natura del servizio — Nessuna sostituzione degli obblighi HACCP

    L'App è uno **strumento di supporto** alla documentazione e al monitoraggio operativo. **Non sostituisce**:

    - il piano di autocontrollo igienico-sanitario approvato per il locale;
    - le verifiche e ispezioni delle Autorità competenti;
    - la formazione obbligatoria del personale;
    - le procedure aziendali e le schede di lavoro validate dal titolare dell'attività.

    Soglie, promemoria, alert e report generati automaticamente hanno valore **indicativo** e vanno verificati dal personale qualificato.

    ## 5. Dati, backup e disponibilità

    I dati operativi sono memorizzati **principalmente sul dispositivo** (SwiftData / archivio locale). Il Fornitore non garantisce il recupero di dati persi per:

    - reset del dispositivo senza backup;
    - malfunzionamenti hardware;
    - cancellazione volontaria tramite funzioni di reset dell'App.

    La copia opzionale dei PDF su **iCloud Drive** è gestita tramite infrastrutture Apple, attivabile dal MASTER in Impostazioni. Il Fornitore non ha accesso diretto al contenuto dei file su iCloud dell'utente.

    ## 6. Aggiornamenti e manutenzione

    Il Fornitore può rilasciare aggiornamenti per correzioni, miglioramenti o adeguamenti normativi. Alcuni aggiornamenti possono essere necessari per il continuo utilizzo dell'App.

    ## 7. Proprietà intellettuale

    Marchi, interfaccia grafica, codice sorgente e documentazione dell'App sono di proprietà del Fornitore o dei rispettivi licenzianti. Nessun diritto di proprietà intellettuale è trasferito all'utente oltre alla licenza d'uso limitata sopra descritta.

    ## 8. Limitazione di responsabilità

    Nei limiti consentiti dalla legge applicabile, il Fornitore **non risponde** di:

    - errori o omissioni nei dati inseriti dagli utenti;
    - mancata esecuzione dei controlli HACCP;
    - sanzioni, sequestri o provvedimenti delle Autorità derivanti da violazioni imputabili al titolare dell'attività;
    - danni indiretti, perdita di profitto o interruzione dell'attività;
    - incompatibilità con procedure interne non comunicate al Fornitore.

    La responsabilità complessiva del Fornitore, ove non esclusa, è limitata all'importo corrisposto per l'App nei **12 mesi** precedenti l'evento dannoso, salvo dolo o colpa grave.

    ## 9. Durata e recesso

    I Termini restano efficaci finché l'App è installata e utilizzata. L'utente può cessare l'uso disinstallando l'App ed esportando i dati necessari prima della cancellazione.

    Il Fornitore può sospendere l'accesso in caso di violazione grave dei Termini o uso fraudolento.

    ## 10. Legge applicabile e foro competente

    I Termini sono regolati dalla legge **\(LegalConstants.governingLaw)**. Per controversie con clienti professionali (ristoratori, imprese) è competente il \(LegalConstants.competentCourt), salvo norme inderogabili a tutela del consumatore.

    ## 11. Modifiche ai Termini

    Il Fornitore può aggiornare i Termini. Le modifiche sostanziali saranno comunicate tramite l'App o via email ai recapiti configurati. L'uso continuato dopo la pubblicazione costituisce accettazione.

    \(LegalConstants.documentFooter)
    """

    // MARK: - Privacy Policy

    static let privacy = """
    ## 1. Titolare del trattamento

    **\(LegalConstants.dataController)**
    Sede: \(LegalConstants.registeredOffice)
    P.IVA / C.F.: \(LegalConstants.vatNumber)
    Email privacy: **\(LegalConstants.privacyEmail)**
    Email supporto: **\(LegalConstants.supportEmail)**

    ## 2. Ambito di applicazione

    La presente informativa descrive il trattamento dei dati personali effettuato tramite l'App **\(LegalConstants.appName)** ai sensi del Regolamento (UE) 2016/679 («GDPR») e del D.Lgs. 196/2003 come modificato dal D.Lgs. 101/2018.

    ### Ruoli nel trattamento

    - **Dati relativi all'uso del software e al rapporto con il Fornitore** (es. richieste di assistenza, aggiornamenti): il Titolare è **\(LegalConstants.dataController)**.
    - **Dati operativi HACCP del locale** (temperature, checklist, tracciabilità, nomi operatori, foto prodotti, registri): il **Titolare** è in genere il **titolare dell'attività alimentare** (ristoratore / società gestrice). **\(LegalConstants.dataController)** agisce come **Responsabile del trattamento** per conto del cliente, limitatamente alla fornitura e manutenzione dell'App sul dispositivo, secondo quanto previsto nei Termini e nella sintesi dell'Accordo di Responsabile (sezione dedicata nell'App).

    ## 3. Categorie di dati trattati

    | Categoria | Esempi | Obbligatorietà |
    |---|---|---|
    | Dati identificativi utenti | Nome, ruolo, PIN (hash), email/telefono opzionali | Necessari per accesso |
    | Dati operativi HACCP | Temperature, controlli, NC, lotti, fornitori | Necessari per finalità HACCP |
    | Dati del locale | Ragione sociale, indirizzo, logo | Configurazione |
    | Immagini | Foto prodotti / controlli | Facoltative |
    | Dati tecnici | Versione app, log diagnostici locali, preferenze | Funzionamento |
    | Documenti PDF | Registri e report generati | Conservazione obblighi HACCP |

    **Non trattiamo** dati sanitari nel senso dell'art. 9 GDPR, salvo che l'utente inserisca volontariamente informazioni non richieste nei campi note.

    ## 4. Finalità e basi giuridiche

    1. **Erogazione del servizio** — registrazione controlli, generazione documenti, gestione utenti. Base: **esecuzione del contratto** (art. 6.1.b GDPR) e, per il ristoratore, **obbligo legale** HACCP (art. 6.1.c).
    2. **Sicurezza e audit** — log di accesso, tracciamento modifiche critiche. Base: **legittimo interesse** (art. 6.1.f) e obblighi di accountability.
    3. **Backup PDF su iCloud** (se attivato dal MASTER). Base: **consenso / scelta dell'interessato** tramite impostazione esplicita (art. 6.1.a).
    4. **Assistenza tecnica**. Base: **esecuzione del contratto** o **consenso** per comunicazioni non strettamente necessarie.
    5. **Adempimenti legali** (es. risposte ad Autorità). Base: **obbligo di legge** (art. 6.1.c).

    ## 5. Modalità del trattamento

    I dati sono trattati con strumenti informatici e telematici, con misure di sicurezza adeguate (crittografia del dispositivo Apple, hash del PIN, accesso profilato, container app isolato).

    ## 6. Destinatari e trasferimenti

    I dati **non sono venduti** né ceduti per marketing di terzi.

    Possibili destinatari / sub-responsabili:

    - **Apple Inc.** — infrastruttura iOS, iCloud Drive (se abilitato), App Store; trattamento secondo le policy Apple.
    - **Personale autorizzato del Fornitore** — solo per assistenza, su segnalazione del cliente.

    Non sono previsti trasferimenti extra-UE da parte del Fornitore, salvo quelli eventualmente effettuati da Apple in qualità di fornitore di piattaforma (Standard Contractual Clauses / decisioni di adeguatezza).

    ## 7. Conservazione

    - Dati operativi: fino a cancellazione da parte del MASTER / disinstallazione, e comunque per il periodo richiesto dalla normativa HACCP e dal piano di autocontrollo del locale (in genere **minimo 6–12 mesi** o più per registri specifici).
    - Documenti PDF: secondo impostazioni di archivio e obblighi del titolare dell'attività.
    - Dati di assistenza: fino a **24 mesi** dalla chiusura del ticket.

    ## 8. Diritti dell'interessato

    In qualità di interessato hai diritto di:

    - accesso, rettifica, cancellazione;
    - limitazione e opposizione (ove applicabile);
    - portabilità dei dati forniti in formato strutturato;
    - revoca del consenso (senza pregiudicare trattamenti precedenti);
    - proporre reclamo al **Garante per la protezione dei dati personali** (www.garanteprivacy.it).

    Per dati operativi HACCP rivolgersi prioritariamente al **titolare dell'attività** (MASTER / datore di lavoro). Per trattamenti di cui è titolare il Fornitore: **\(LegalConstants.privacyEmail)**.

    ## 9. Minori

    L'App non è destinata a minori di 16 anni. Non raccogliamo consapevolmente dati di minori.

    ## 10. Modifiche all'informativa

    Aggiornamenti saranno pubblicati in App (Impostazioni → Info App) con indicazione della data di revisione.

    \(LegalConstants.documentFooter)
    """

    // MARK: - Cookie e tecnologie

    static let cookies = """
    ## 1. Premessa — App nativa, non sito web

    **\(LegalConstants.appName)** è un'applicazione nativa per iPad/iPhone. **Non utilizza cookie di browser** né tecnologie analoghe tipiche dei siti internet (es. pixel di tracciamento pubblicitario, Google Analytics web).

    La presente informativa descrive, in conformità al GDPR e alla normativa ePrivacy applicabile, le **tecnologie di archiviazione e identificazione** utilizzate dall'App, con finalità trasparenti per l'utente.

    ## 2. Tecnologie utilizzate

    ### 2.1 Archivio locale (SwiftData / file system)

    | Tecnologia | Finalità | Durata | Base giuridica |
    |---|---|---|---|
    | Database SwiftData | Registri HACCP, utenti, impostazioni | Fino a cancellazione / reset | Contratto / obbligo HACCP |
    | File PDF locali | Documenti ufficiali generati | Secondo policy archivio | Obbligo legale / contratto |
    | UserDefaults | Preferenze UI, flag funzionali | Fino a disinstallazione | Legittimo interesse |

    Questi dati restano **sul dispositivo** e non sono accessibili al Fornitore da remoto.

    ### 2.2 Identificatori e sicurezza

    - **PIN utente**: memorizzato solo in forma **hash** (non reversibile).
    - **Face ID / Touch ID**: gestiti dal Secure Enclave Apple; il Fornitore non riceve le impronte o i dati biometrici.
    - **UUID dispositivo / account iCloud**: utilizzati da Apple per il servizio iCloud, non per profilazione commerciale da parte del Fornitore.

    ### 2.3 iCloud Drive (opzionale)

    Se il MASTER attiva «Copia automatica PDF su iCloud», i file PDF vengono replicati nel container iCloud dell'app (`iCloud.com.haccpmanager.app`). Apple agisce come titolare/responsabile secondo i propri termini.

    **Nessun sync automatico** dei database operativi (temperature, checklist, ecc.) verso cloud del Fornitore.

    ### 2.4 Notifiche locali

    L'App può inviare **notifiche locali** (promemoria checklist, scadenze) senza trasmettere contenuti a server esterni del Fornitore.

    ### 2.5 Fotocamera e libreria foto

    L'accesso a camera e galleria avviene **solo su richiesta esplicita** (es. foto tracciabilità) e richiede autorizzazione iOS. Le immagini restano nei record locali.

    ## 3. Cosa NON facciamo

    - Nessuna pubblicità comportamentale.
    - Nessun tracciamento cross-app per profilazione.
    - Nessuna vendita di dati a terzi.
    - Nessun cookie di terze parti per marketing.

    ## 4. Gestione delle preferenze

    - **iCloud PDF**: disattivabile in Impostazioni → Dati e Backup.
    - **Notifiche**: gestibili in Impostazioni iOS → Notifiche → \(LegalConstants.appName).
    - **Biometria**: attivabile/disattivabile in Impostazioni → Sicurezza.
    - **Reset completo**: disponibile per il MASTER in Dati e Backup (cancella dati locali).

    ## 5. Contatti

    Per domande su questa informativa: **\(LegalConstants.privacyEmail)**

    \(LegalConstants.documentFooter)
    """

    // MARK: - Note legali HACCP

    static let legal = """
    ## 1. Natura del software

    **\(LegalConstants.appName)** è un software di supporto alla gestione documentale e operativa del sistema HACCP. Non costituisce certificazione, validazione ASL né parere igienico-sanitario.

    ## 2. Riferimenti normativi (indicativi)

    L'App è progettata per facilitare l'adempimento di obblighi derivanti da, tra l'altro:

    - Regolamento (CE) n. 852/2004 sull'igiene dei prodotti alimentari;
    - D.Lgs. 193/2007 (attuazione regolamenti CE nn. 852/2004, 853/2004, 854/2004);
    - Linee guida e circolari regionali in materia di autocontrollo.

    La conformità effettiva dell'esercizio resta responsabilità del **titolare dell'attività alimentare** e del suo consulente / Responsabile HACCP.

    ## 3. Registri e documenti generati

    I PDF e i registri esportati hanno valore probatorio nella misura in cui:

    - i dati inseriti rispecchiano i controlli effettivamente eseguiti;
    - le registrazioni sono complete, veritiere e tempestive;
    - sono conservati per i periodi previsti dal piano HACCP e dalla legge.

    La checksum SHA-256 e gli identificativi documento servono all'integrità tecnica del file, non sostituiscono la firma digitale qualificata ove richiesta.

    ## 4. Limitazioni tecniche

    - Le soglie di temperatura configurabili sono parametri operativi del locale, non valori normativi universali.
    - Gli alert automatici non garantiscono il rilevamento di ogni non conformità.
    - La disponibilità dell'App dipende dal dispositivo, dalla batteria e dalla corretta formazione degli operatori.

    ## 5. Marchi e attribuzioni

    Apple, iPad, iPhone, iCloud, Face ID e Touch ID sono marchi di Apple Inc. \(LegalConstants.dataController) non è affiliata né approvata da Apple oltre alla distribuzione tramite App Store.

    ## 6. Avvertenza

    I testi legali nell'App hanno carattere informativo. Per adempimenti specifici del proprio esercizio consultare il proprio Responsabile HACCP, legale di fiducia e le Autorità competenti.

    \(LegalConstants.documentFooter)
    """

    // MARK: - Responsabile del trattamento (sintesi)

    static let dataProcessor = """
    ## Accordo sul trattamento dei dati — Sintesi per il Cliente (Titolare dell'attività)

    Il presente documento riassume i principali obblighi tra il **Cliente** (titolare dell'attività alimentare che utilizza l'App) e **\(LegalConstants.dataController)** («Responsabile») ai sensi dell'art. 28 GDPR.

    ### 1. Oggetto

    Il Responsabile tratta dati personali per conto del Cliente esclusivamente per fornire l'App \(LegalConstants.appName): hosting locale sul dispositivo, generazione PDF, funzioni di backup opzionale su iCloud scelto dal Cliente, assistenza tecnica.

    ### 2. Istruzioni del Titolare

    Il Responsabile tratta i dati **solo su istruzioni documentate** del Cliente (configurazione App, policy interne, richieste di assistenza), salvo obblighi di legge.

    ### 3. Misure di sicurezza

    - accesso profilato e autenticazione PIN / biometria;
    - isolamento dati per ristorante (multi-tenant sul dispositivo);
    - assenza di accesso remoto del Responsabile ai database operativi;
    - audit log per operazioni critiche ove implementato.

    ### 4. Sub-responsabili

    Sub-responsabili autorizzati: **Apple Inc.** (piattaforma iOS, iCloud opzionale). Elenco aggiornato su richiesta a **\(LegalConstants.privacyEmail)**.

    ### 5. Assistenza al Titolare

    Il Responsabile assiste il Cliente, nella misura del possibile, per:

    - risposta a richieste di esercizio diritti degli interessati (accesso, cancellazione);
    - notifica di violazioni dei dati personali (data breach) se rilevate e imputabili al software;
    - informazioni per DPIA, se richieste per l'introduzione dell'App in contesti specifici.

    ### 6. Restituzione e cancellazione

    Alla disinstallazione o su richiesta del Cliente, i dati restano sul dispositivo fino a cancellazione esplicita tramite funzioni App. Il Responsabile non conserva copie centralizzate dei registri HACCP del Cliente.

    ### 7. Contatti

    - Titolare (Cliente): il ristoratore / società indicata in configurazione App.
    - Responsabile: \(LegalConstants.dataController) — \(LegalConstants.privacyEmail)

    Per l'accordo completo art. 28 GDPR contattare il Fornitore. La versione integrale può essere fornita in fase di contrattazione commerciale o su richiesta del MASTER.

    \(LegalConstants.documentFooter)
    """

    // MARK: - Licenze

    static let licenses = """
    ## Componenti software

    **\(LegalConstants.appName)** utilizza principalmente framework Apple distribuiti con Xcode e iOS/iPadOS:

    - SwiftUI, SwiftData, Foundation, Combine
    - UserNotifications, LocalAuthentication, CryptoKit
    - QuickLook, UIKit

    L'uso di tali componenti è soggetto ai **Apple Developer Program License Agreement** e alle condizioni di licenza del sistema operativo Apple.

    ## Licenza applicazione

    Il codice sorgente proprietario dell'App è di titolarità di **\(LegalConstants.dataController)**. Nessuna parte può essere riprodotta o distribuita senza autorizzazione scritta, salvo quanto consentito dalla legge sul diritto d'autore.

    ## Librerie di terze parti

    Al momento del rilascio corrente non sono integrate librerie open source esterne con obbligo di attribuzione pubblica nell'App. Eventuali future dipendenze saranno elencate in questa sezione con link ai rispettivi file LICENSE.

    ## Segnalazioni

    Per questioni su licenze o attribuzioni mancanti: **\(LegalConstants.supportEmail)**

    \(LegalConstants.documentFooter)
    """

    // MARK: - Supporto

    static let support = """
    ## Assistenza tecnica

    **\(LegalConstants.dataController)** fornisce supporto per l'App **\(LegalConstants.appName)** ai clienti autorizzati.

    ### Prima di contattarci

    1. Verifica di usare l'**ultima versione** dell'App (Impostazioni → Info App).
    2. Controlla **spazio disponibile** sul dispositivo (Impostazioni → Dati e Backup).
    3. Se usi backup PDF, verifica **iCloud Drive** attivo e account collegato.
    4. Per problemi di accesso, contatta l'utente **MASTER** del tuo locale.

    ### Come contattarci

    - Email: **\(LegalConstants.supportEmail)**
    - Indica: versione app, modello dispositivo (es. iPad Pro 11"), sistema operativo, descrizione del problema e screenshot se utile.

    ### Orari indicativi

    Lunedì – venerdì, 9:00 – 18:00 (ora italiana), esclusi festivi nazionali.

    ### Urgenze HACCP in sede

    Per non conformità alimentari, controlli ASL o questioni igienico-sanitarie urgenti rivolgersi al **Responsabile HACCP** del locale e alle Autorità competenti. Il supporto tecnico del Fornitore **non gestisce** emergenze sanitarie o ispezioni in corso.

    ### SLA

    I tempi di risposta possono variare in base al contratto di manutenzione sottoscritto con il Cliente. In assenza di contratto specifico, le richieste vengono evase per ordine di arrivo nei giorni lavorativi.

    \(LegalConstants.documentFooter)
    """
}
