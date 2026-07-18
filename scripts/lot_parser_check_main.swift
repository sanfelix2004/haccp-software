import Foundation

@main
enum LotParserCheckMain {
    static func main() {
        let expiryFailures = ExpiryDateParserSelfCheck.run()
        let sanitizerFailures = LabelLotSanitizerSelfCheck.run()
        let dateFailures = HACCPDateNormalizerSelfCheck.run()
        let allFailures = expiryFailures.map { "[expiry] \($0)" }
            + sanitizerFailures.map { "[sanitizer] \($0)" }
            + dateFailures.map { "[date] \($0)" }

        if allFailures.isEmpty {
            print("OK — regressione lotto/scadenza superata (ExpiryDateParser + LabelLotSanitizer + HACCPDateNormalizer)")
        } else {
            print("FALLITI \(allFailures.count) casi:")
            for failure in allFailures {
                print("  • \(failure)")
            }
            exit(1)
        }
    }
}

#if DEBUG
enum LabelLotSanitizerSelfCheck {
    static func run() -> [String] {
        var failures: [String] = []

        let acceptLots = ["L0526", "L6036BH099", "L52400V757", "AB12CD", "240115A", "BATCH-99", "52400V757", "6036BH099"]
        for lot in acceptLots {
            if LabelLotSanitizer.validateLot(lot) == nil {
                failures.append("Lotto valido rifiutato: \(lot)")
            }
        }

        if LabelLotSanitizer.validateLot("L6036BH099") != "L6036BH099" {
            failures.append("L6036BH099 deve mantenere la L iniziale")
        }

        if LabelLotSanitizer.validateLot("6036BH099", rawContext: #"{"lotto":"L6036BH099"}"#) != "L6036BH099" {
            failures.append("L6036BH099: ripristino L da JSON fallito")
        }

        if LabelLotSanitizer.validateLot("9330B8", rawContext: #"{"raw_stamp_line":"L9330 B8 00:09"}"#) != "L9330B8" {
            failures.append("L9330B8: ripristino L da riga stampa fallito")
        }

        if LabelStampLineParser.extractLot(from: "Best before 26NOV 2025 L9330 B8 00:09") != "L9330B8" {
            failures.append("Estrazione lotto da riga tappo fallita")
        }

        if LabelStampLineParser.extractLot(from: "30490206AK-25 10:55:36") != "30490206AK-25" {
            failures.append("Estrazione lotto 30490206AK-25 fallita")
        }

        if LabelStampLineParser.extractLot(from: "LOT 272019\nSELL BY 09/02") != "272019" {
            failures.append("Estrazione lotto LOT 272019 fallita")
        }

        if LabelStampLineParser.extractLot(from: "15701 00:44") != "15701" {
            failures.append("Estrazione lotto 15701 da orario fallita")
        }

        if LabelStampLineParser.extractLot(from: "(10)ABC12345") != "ABC12345" {
            failures.append("Estrazione lotto GS1 (10) fallita")
        }

        if LabelStampLineParser.extractLot(from: "N° L24056") != "L24056"
            && LabelStampLineParser.extractLot(from: "N° L24056") != "24056" {
            failures.append("Estrazione lotto N° fallita")
        }

        if LabelStampLineParser.extractLot(from: "240526 14:32 4B22") != "4B22" {
            failures.append("Estrazione lotto implicito 4B22 fallita")
        }

        if LabelStampLineParser.extractLot(from: "BATCH #987-XYZ") != "#987-XYZ"
            && LabelStampLineParser.extractLot(from: "BATCH #987-XYZ") != "987-XYZ" {
            failures.append("Estrazione lotto BATCH #987-XYZ fallita")
        }

        if LabelStampLineParser.extractLot(from: "31/08/26\n08:18H-FYB") != "08:18H-FYB" {
            failures.append("Estrazione lotto yogurt 08:18H-FYB fallita")
        }

        if LabelStampLineParser.extractLot(from: "Best Before End: 11/2027\nBatch number: 44464") != "44464" {
            failures.append("Estrazione lotto Batch number 44464 fallita")
        }

        if LabelLotSanitizer.validateLot("number") != nil
            || LabelLotSanitizer.validateLot("NUMBER") != nil
            || LabelLotSanitizer.validateLot("batch") != nil {
            failures.append("Parola etichetta number/batch accettata come lotto")
        }

        if let batchExpiry = ExpiryDateParser.parse(from: "Best Before End: 11/2027") {
            let c = Calendar.current.dateComponents([.day, .month, .year], from: batchExpiry)
            if c.month != 11 || c.year != 2027 {
                failures.append("Best Before End 11/2027 non parsata come nov 2027")
            }
        } else {
            failures.append("Best Before End 11/2027 non parsata")
        }

        if LabelLotSanitizer.validateLot("LATTY") != nil
            || LabelLotSanitizer.validateLot("LATTE") != nil
            || LabelLotSanitizer.validateLot("GRECO") != nil {
            failures.append("Marketing OCR (LATTY/LATTE/GRECO) accettato come lotto")
        }

        if LabelLotSanitizer.validateLot("08:18H-FYB") != "08:18H-FYB" {
            failures.append("Lotto industriale 08:18H-FYB rifiutato")
        }

        if LabelStampLineParser.parseExpiry(from: "240526 14:32 4B22") == nil {
            failures.append("Scadenza GGMMAA implicita non parsata")
        }

        if LabelLotSanitizer.validateLot("SELL") != nil {
            failures.append("Parola chiave SELL accettata come lotto")
        }

        if LabelLotSanitizer.validateLot("LATTE") != nil
            || LabelLotSanitizer.validateLot("YOGURT") != nil
            || LabelLotSanitizer.validateLot("GRECO") != nil {
            failures.append("Nome prodotto/marketing accettato come lotto")
        }

        if LabelLotSanitizer.validateLot("to_found") != nil
            || LabelLotSanitizer.validateLot("lotto_found") != nil
            || LabelLotSanitizer.clean("lotto_found") == "to_found" {
            failures.append("Artefatto schema to_found/lotto_found accettato come lotto")
        }

        if LabelLotSanitizer.validateLot("314902058K-25") != "314902058K-25" {
            failures.append("Validazione lotto con trattino fallita")
        }

        if LabelLotSanitizer.validateLot("52400Y757") != "52400V757" {
            failures.append("Correzione Y→V non applicata su 52400Y757")
        }

        if LabelStampLineParser.parseExpiry(from: "23/08/2026 06:08") == nil {
            failures.append("Riga data+orario non parsata")
        }

        if LabelStampLineParser.expiryMatchesMisreadProductionTime(
            expiry: Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 6))!,
            context: #"{"scadenza":"06:08"}"#
        ) == false {
            failures.append("Orario produzione non rilevato come falso positivo")
        }

        let rejectLots = ["8012345678901", "12/2029", "2029-12-31", "261205", "12/29"]
        for lot in rejectLots {
            if LabelLotSanitizer.validateLot(lot) != nil {
                failures.append("Lotto invalido accettato: \(lot)")
            }
        }

        return failures
    }
}
#endif
