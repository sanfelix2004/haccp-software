import Foundation

/// Durata indicativa di conservazione (giorni) per alimenti in ingresso.
enum IncomingFoodShelfLifeDefaults {
    /// Durata per categoria merce (valori HACCP realistici, indicativi).
    static func days(for category: GoodsCategory) -> Int {
        switch category {
        case .freshFish:
            return 1
        case .freshMeat:
            return 2
        case .perishable, .combined:
            return 3
        case .refrigerated:
            return 5
        case .produce:
            return 5
        case .packaged:
            return 30
        case .dryProducts:
            return 180
        case .frozen, .frozenProducts:
            return 365
        case .longShelfLife:
            return 365
        case .all:
            return 7
        }
    }

    /// Durata con override per nome noto (seed catalogo / nomi comuni).
    static func days(forName name: String, category: GoodsCategory) -> Int {
        let normalized = normalize(name)
        if let specific = nameOverrides[normalized] {
            return specific
        }
        for (key, value) in nameOverrides where normalized.contains(key) {
            return value
        }
        return days(for: category)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static let nameOverrides: [String: Int] = [
        "carni fresche": 2,
        "pesce fresco": 1,
        "uova": 28,
        "uovo": 28,
        "latte": 5,
        "latticini": 5,
        "panna": 5,
        "mascarpone": 5,
        "formaggio": 14,
        "pecorino": 21,
        "parmigiano": 30,
        "mozzarella": 3,
        "verdura": 5,
        "frutta": 5,
        "ortofrutticoli": 5,
        "prodotti secchi": 180,
        "farina": 180,
        "riso": 365,
        "pasta secca": 365,
        "surgelat": 365,
        "congelat": 365,
        "scatolame": 365,
        "lunga conservazione": 365,
        "confezionat": 30,
        "polpo": 2,
        "carne": 2,
        "pesce": 1,
        "pollo": 2,
        "manzo": 2,
        "maiale": 2,
        "basilico": 3,
        "olio": 180,
        "burro": 30,
        "lievito": 90,
        "gelatina": 365,
        "amido": 365,
        "zucchero": 365,
        "cioccolato": 180,
        "caffè": 180,
        "caffe": 180,
        "savoiardi": 120,
        "biscotti": 120,
        "pinoli": 90,
        "aglio": 30,
        "cipolla": 30,
        "pomodoro": 7,
        "pomodoro pelato": 30,
        "pomodoro fresco": 5,
        "bufala": 3,
        "alici": 1,
        "alici fresche": 1,
        "tonno fresco": 1,
        "gamberi": 1,
        "gambero": 1,
        "branzino": 1,
        "orata": 1,
        "spigola": 1,
        "calamaro": 1,
        "calamari": 1,
        "vino": 365,
        "aceto": 365,
        "capperi": 365,
        "olive": 180,
        "peperone": 5,
        "melanzana": 5,
        "zucchina": 5,
        "prezzemolo": 3,
        "rucola": 3,
        "lattuga": 3,
        "limone": 14,
        "arancia": 14,
        "miele": 365,
        "marmellata": 180,
        "nutella": 180,
        "prosciutto": 5,
        "speck": 14,
        "pancetta": 7,
        "salmone": 1,
        "merluzzo": 1,
        "cozze": 1,
        "vongole": 1,
        "seppia": 1,
        "noci": 90,
        "mandorle": 120,
        "pangrattato": 90,
        "brodo": 180,
        "passata": 30,
        "concentrato pomodoro": 30,
    ]
}
