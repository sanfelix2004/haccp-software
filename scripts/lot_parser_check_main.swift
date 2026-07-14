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

        if LabelLotSanitizer.validateLot("SELL") != nil {
            failures.append("Parola chiave SELL accettata come lotto")
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
