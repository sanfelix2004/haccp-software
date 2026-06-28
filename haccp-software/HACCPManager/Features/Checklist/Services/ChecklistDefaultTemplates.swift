import Foundation

enum ChecklistDefaultTemplates {
    private static func pf(_ title: String) -> ChecklistItemTemplateDraft {
        .init(title: title, description: "", type: .passFail, isRequired: true, requiresNoteIfFailed: true)
    }

    /// Modelli HACCP predefiniti: giornalieri sempre visibili; settimanali/mensili/annuali just-in-time.
    static let definitions: [SuggestedChecklistTemplate] = [
        // —— Giornalieri (tab Oggi ogni giorno) ——
        .init(
            title: "Apertura cucina",
            description: "Controlli apertura turno cucina.",
            category: .opening,
            frequency: .daily,
            scheduledHour: 9,
            scheduledMinute: 0,
            allowsBulkPass: false,
            items: [
                pf("Sapone e carta mani disponibili"),
                pf("Superfici di lavoro pulite"),
                pf("Frigoriferi in ordine"),
                pf("Attrezzature pulite"),
                pf("Rifiuti vuoti"),
                pf("Area preparazione pronta")
            ]
        ),
        .init(
            title: "Chiusura cucina",
            description: "Controlli chiusura turno cucina.",
            category: .closing,
            frequency: .daily,
            scheduledHour: 23,
            scheduledMinute: 0,
            allowsBulkPass: false,
            items: [
                pf("Piani sanificati"),
                pf("Pavimenti puliti"),
                pf("Rifiuti smaltiti"),
                pf("Alimenti coperti ed etichettati"),
                pf("Frigoriferi chiusi"),
                pf("Attrezzature spente/pulite")
            ]
        ),
        .init(
            title: "Pulizie giornaliere",
            description: "Pulizie operative quotidiane.",
            category: .cleaning,
            frequency: .daily,
            scheduledHour: 21,
            scheduledMinute: 0,
            allowsBulkPass: false,
            items: [
                pf("Banco preparazione sanificato"),
                pf("Lavelli puliti"),
                pf("Pavimenti lavati"),
                pf("Utensili lavati"),
                pf("Maniglie e superfici toccate sanificate")
            ]
        ),
        .init(
            title: "Igiene personale",
            description: "Controlli igiene personale staff.",
            category: .personalHygiene,
            frequency: .daily,
            scheduledHour: 10,
            scheduledMinute: 0,
            allowsBulkPass: false,
            items: [
                pf("Mani lavate"),
                pf("Divisa pulita"),
                pf("Capelli coperti se necessario"),
                pf("Guanti disponibili"),
                pf("Nessun oggetto personale in zona preparazione")
            ]
        ),
        .init(
            title: "Conservazione alimenti",
            description: "Controlli conservazione e stoccaggio.",
            category: .foodStorage,
            frequency: .daily,
            scheduledHour: 12,
            scheduledMinute: 0,
            allowsBulkPass: false,
            items: [
                pf("Prodotti coperti"),
                pf("Crudo e cotto separati"),
                pf("Scadenze visibili"),
                pf("Etichette leggibili"),
                pf("Nessun prodotto scaduto")
            ]
        ),
        .init(
            title: "Ricevimento merci",
            description: "Controlli ingresso merci.",
            category: .receivingGoods,
            frequency: .daily,
            scheduledHour: 8,
            scheduledMinute: 30,
            allowsBulkPass: false,
            items: [
                pf("Imballi integri"),
                pf("Prodotti controllati"),
                pf("Temperature verificate se necessario"),
                pf("Lotti/documenti presenti"),
                pf("Prodotti non conformi separati")
            ]
        ),

        // —— Settimanali (lunedì mattina, visibili solo quel giorno) ——
        .init(
            title: "Pulizia filtri",
            description: "Sanificazione filtri cappe aspiranti e lavastoviglie industriale.",
            category: .cleaning,
            frequency: .weekly,
            scheduledHour: 9,
            scheduledMinute: 0,
            scheduleWeekday: 2,
            bulkPassTitle: "Tutti i filtri sono stati sanificati",
            items: [
                pf("Filtri cappe aspiranti sanificati"),
                pf("Filtri lavastoviglie industriale sanificati"),
                pf("Filtri sostituiti se danneggiati")
            ]
        ),
        .init(
            title: "Ispezione magazzino secco",
            description: "Controllo muffe, umidità e infestanti tra scaffali merci non deperibili.",
            category: .foodStorage,
            frequency: .weekly,
            scheduledHour: 9,
            scheduledMinute: 30,
            scheduleWeekday: 2,
            bulkPassTitle: "Magazzino secco conforme",
            items: [
                pf("Nessun segno di muffa o umidità"),
                pf("Scaffali farine e scatolame integri"),
                pf("Nessun segno di infestanti"),
                pf("Prodotti stoccati a terra su pallet/ripiani")
            ]
        ),
        .init(
            title: "Produttore di ghiaccio",
            description: "Svuotamento e sanificazione macchina del ghiaccio.",
            category: .equipment,
            frequency: .weekly,
            scheduledHour: 10,
            scheduledMinute: 0,
            scheduleWeekday: 2,
            bulkPassTitle: "Macchina ghiaccio sanificata",
            items: [
                pf("Serbatoio svuotato completamente"),
                pf("Sanificazione interna eseguita"),
                pf("Filtro acqua pulito"),
                pf("Ghiaccio prodotto conforme")
            ]
        ),

        // —— Mensili (1° del mese) ——
        .init(
            title: "Taratura termometri",
            description: "Verifica termometri frigoriferi e sonde a spillone (ghiaccio fuso 0 °C).",
            category: .equipment,
            frequency: .monthly,
            scheduledHour: 10,
            scheduledMinute: 0,
            scheduleDayOfMonth: 1,
            bulkPassTitle: "Tutti i termometri sono tarati",
            items: [
                pf("Termometro frigo preparazione"),
                pf("Termometro frigo conservazione"),
                pf("Termometro cella carni"),
                pf("Termometro cella pesce"),
                pf("Sonda a spillone verificata")
            ]
        ),
        .init(
            title: "Stato guarnizioni frigoriferi",
            description: "Controllo chiusura ermetica portelloni frighi e celle.",
            category: .equipment,
            frequency: .monthly,
            scheduledHour: 10,
            scheduledMinute: 30,
            scheduleDayOfMonth: 1,
            bulkPassTitle: "Tutte le guarnizioni sono integre",
            items: [
                pf("Frigo preparazione"),
                pf("Frigo conservazione"),
                pf("Frigo bevande"),
                pf("Cella carni"),
                pf("Cella pesce"),
                pf("Cella surgelati"),
                pf("Abbattitore"),
                pf("Vetrina esposizione")
            ]
        ),
        .init(
            title: "Monitoraggio infestanti",
            description: "Controllo esche/trappole insetti e roditori (registro derattizzazione).",
            category: .custom,
            frequency: .monthly,
            scheduledHour: 11,
            scheduledMinute: 0,
            scheduleDayOfMonth: 1,
            bulkPassTitle: "Tutte le trappole sono conformi",
            items: [
                pf("Trappole insetti verificate e rinnovate"),
                pf("Esche roditori verificate"),
                pf("Nessuna traccia di infestazione"),
                pf("Registro derattizzazione aggiornato")
            ]
        ),

        // —— Annuali (1° gennaio) ——
        .init(
            title: "Analisi acqua potabile",
            description: "Registrazione prelievo campionamento chimico/microbiologico acqua cucina.",
            category: .custom,
            frequency: .annual,
            scheduledHour: 9,
            scheduledMinute: 0,
            scheduleDayOfMonth: 1,
            scheduleMonth: 1,
            allowsBulkPass: false,
            items: [
                pf("Prelievo campione programmato"),
                pf("Documentazione laboratorio archiviata"),
                pf("Esito conforme registrato")
            ]
        ),
        .init(
            title: "Rinnovo attestati HACCP",
            description: "Verifica validità corsi HACCP di tutto il personale.",
            category: .personalHygiene,
            frequency: .annual,
            scheduledHour: 10,
            scheduledMinute: 0,
            scheduleDayOfMonth: 1,
            scheduleMonth: 1,
            bulkPassTitle: "Tutti gli attestati sono validi",
            items: [
                pf("Attestati personale cucina validi"),
                pf("Attestati personale sala validi"),
                pf("Nuovi ingressi formati"),
                pf("Copie attestati archiviate")
            ]
        ),
        .init(
            title: "Manutenzione impianti annuali",
            description: "Sanificazione impianto condizionamento/refrigerazione e controllo antincendio.",
            category: .equipment,
            frequency: .annual,
            scheduledHour: 11,
            scheduledMinute: 0,
            scheduleDayOfMonth: 1,
            scheduleMonth: 1,
            bulkPassTitle: "Tutti gli impianti sono conformi",
            items: [
                pf("Sanificazione impianto condizionamento"),
                pf("Manutenzione impianto refrigerazione"),
                pf("Estintori e sistemi antincendio verificati"),
                pf("Certificati manutenzione archiviati")
            ]
        )
    ]
}
