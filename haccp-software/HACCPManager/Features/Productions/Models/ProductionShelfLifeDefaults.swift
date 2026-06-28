import Foundation

/// Durata indicativa di conservazione (giorni) per piatti/produzioni finite in frigo (+2/+4 °C).
/// Valori HACCP realistici per cucina professionale — da validare nel proprio manuale.
enum ProductionShelfLifeDefaults {

    static func days(forCategory categoryName: String) -> Int {
        switch normalize(categoryName) {
        case "crudi":
            return 1
        case "antipasti":
            return 2
        case "secondi":
            return 2
        case "primi":
            return 3
        case "contorni":
            return 3
        case "dolci":
            return 3
        case "entre", "entree", "entrè":
            return 2
        case "pane":
            return 2
        case "salse vegetali":
            return 4
        default:
            return 3
        }
    }

    static func days(forName name: String, categoryName: String) -> Int {
        let normalized = normalize(name)
        if let specific = nameOverrides[normalized] {
            return specific
        }
        for (key, value) in nameOverrides where normalized.contains(key) {
            return value
        }
        return days(forCategory: categoryName)
    }

    /// Etichetta breve per UI catalogo (es. "2 gg · indicativa").
    static func displayLabel(forName name: String, categoryName: String) -> String {
        "\(days(forName: name, categoryName: categoryName)) gg"
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - Override per piatto (seed catalogo + nomi comuni)

    private static let nameOverrides: [String: Int] = [
        // Crudi / pesce crudo — consumo rapido
        "astice": 1,
        "calamari": 1,
        "calamaro": 1,
        "gambero": 1,
        "gambero bianco": 1,
        "gambero rosso": 1,
        "mazzancolle": 1,
        "pescatrice": 1,
        "pesce spada": 1,
        "ricciola": 1,
        "tartare": 1,
        "tonno": 1,
        "ostriche": 1,
        "razza": 1,
        "polipetti": 1,
        "triglia": 1,
        "sashimi": 1,
        "crudo": 1,

        // Antipasti — pesce lavorato / latticini
        "alici": 2,
        "baccala": 2,
        "baccalà": 2,
        "bufala": 2,
        "mozzarella": 2,
        "cozze": 2,
        "guancia": 2,
        "emulsione": 2,
        "peperone": 2,

        // Secondi cotti
        "branzino": 2,
        "dentice": 2,
        "orata": 2,
        "spigola": 2,
        "sgombro": 2,
        "pagro": 2,
        "cube roll": 2,
        "petto pollo": 2,
        "pollo": 2,
        "tonno in nero": 2,
        "tonno in panatura": 2,

        // Primi
        "ragu": 3,
        "ragù": 3,
        "fonduta": 3,
        "tagliatelle": 3,
        "pomodorino": 3,
        "peperone giallo": 3,

        // Contorni
        "melanzane": 3,
        "zucchine": 3,
        "indivia": 2,
        "cipolla": 3,
        "porro": 3,
        "concasse": 3,

        // Salse / basi vegetali
        "salsa": 4,
        "gazpacho": 3,
        "mayo": 3,
        "yogurt": 4,
        "lenticchie": 4,
        "barbabietola": 4,
        "carota": 4,
        "sedano": 4,
        "topinambur": 4,
        "acqua cipolla": 4,

        // Dolci
        "tiramisu": 3,
        "tiramisù": 3,
        "panna cotta": 3,
        "mousse": 3,
        "cheesecake": 3,
        "crostata": 3,
        "semifreddo": 3,
        "frutta": 2,
        "gelato": 7,
        "sorbetto": 7,

        // Pane / entrè
        "pane": 2,
        "cialdella": 2,
        "mousse menta": 2,
    ]
}

extension Production {
    /// Giorni conservazione mostrati in catalogo (espliciti o indicativi da mappa HACCP).
    var catalogShelfLifeDays: Int {
        defaultShelfLifeDays
    }

    var catalogShelfLifeLabel: String {
        "\(catalogShelfLifeDays) gg"
    }
}
