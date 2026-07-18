import XCTest
import Foundation
@testable import LabelScannerV2

final class FormatCatalogTests: XCTestCase {
    private let interpreter = RegexFallbackInterpreter()

    // MARK: - Scadenze numeriche

    func testExpirySlashDotDash() throws {
        assertExpiry("31/08/26", day: 31, month: 8, year: 2026)
        assertExpiry("31/08/2026", day: 31, month: 8, year: 2026)
        assertExpiry("31.08.26", day: 31, month: 8, year: 2026)
        assertExpiry("31-08-2026", day: 31, month: 8, year: 2026)
        assertExpiry("26.07.2026", day: 26, month: 7, year: 2026)
    }

    func testExpiryUSVsEUDisambiguation() throws {
        // EU: giorno > 12
        assertExpiry("31/08/26", day: 31, month: 8, year: 2026)
        // US: mese ≤ 12 e giorno > 12 nel secondo slot
        assertExpiry("08/31/26", day: 31, month: 8, year: 2026)
    }

    func testExpiryCompactDigits() throws {
        assertExpiry("EXP 310826", day: 31, month: 8, year: 2026)
        assertExpiry("SCAD 31082026", day: 31, month: 8, year: 2026)
        // AAMMDD import
        let yymmdd = interpreter.extractExpiry(from: "EXP 260831")
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(yymmdd.date))
        XCTAssertEqual(comps.day, 31)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.year, 2026)
    }

    func testExpiryMonthYearEndOfMonth() throws {
        assertExpiryMonthEnd("Best Before End: 08/2026", month: 8, year: 2026)
        assertExpiryMonthEnd("TMC 08/26", month: 8, year: 2026)
        assertExpiryMonthEnd("BBE 0826", month: 8, year: 2026)
        assertExpiryMonthEnd("11/2027", month: 11, year: 2027)
    }

    func testExpiryTextualMonths() throws {
        assertExpiry("31 AGO 26", day: 31, month: 8, year: 2026)
        assertExpiry("15 DIC 2026", day: 15, month: 12, year: 2026)
        assertExpiry("31 AUG 26", day: 31, month: 8, year: 2026)
        assertExpiry("12 DEC 26", day: 12, month: 12, year: 2026)
        assertExpiryMonthEnd("BEST BEFORE: JUN 26", month: 6, year: 2026)
        assertExpiryMonthEnd("MAR 27", month: 3, year: 2027)
        assertExpiryMonthEnd("MAI 26", month: 5, year: 2026)
        assertExpiryMonthEnd("OKT 27", month: 10, year: 2027)
    }

    // MARK: - Lotti

    func testLotExplicitPrefixes() {
        XCTAssertEqual(interpreter.extractLot(from: "L.18H-FYB"), "L.18H-FYB")
        XCTAssertEqual(interpreter.extractLot(from: "L:18H-FYB"), "L.18H-FYB")
        XCTAssertEqual(interpreter.extractLot(from: "L. 26F082/B"), "L.26F082/B")
        XCTAssertEqual(interpreter.extractLot(from: "LOT 44464"), "44464")
        XCTAssertEqual(interpreter.extractLot(from: "LOTTO: 44464"), "44464")
        XCTAssertEqual(interpreter.extractLot(from: "BATCH #987-XYZ"), "987-XYZ")
        XCTAssertEqual(interpreter.extractLot(from: "BATCH NUMBER: 44464"), "44464")
        XCTAssertEqual(interpreter.extractLot(from: "B.N. 223A"), "223A")
    }

    func testLotWithProductionTime() {
        XCTAssertEqual(interpreter.extractLot(from: "08:18H-FYB"), "08:18H-FYB")
        XCTAssertEqual(interpreter.extractLot(from: "08:18 18H-FYB"), "18H-FYB")
        XCTAssertEqual(interpreter.extractLot(from: "18H-FYB 08:18"), "18H-FYB")
    }

    func testLotImplicitAndSpecial() {
        XCTAssertEqual(interpreter.extractLot(from: "LA26160"), "LA26160")
        XCTAssertEqual(interpreter.extractLot(from: "261-A04"), "261-A04")
        XCTAssertEqual(interpreter.extractLot(from: "L.26/160"), "L.26/160")
        XCTAssertEqual(interpreter.extractLot(from: "L1"), "L1")
        XCTAssertEqual(interpreter.extractLot(from: "3A", lines: ["LOTTO", "3A"]), "3A")
    }

    func testLotNearDateImplicit() {
        let lot = interpreter.extractLot(
            from: "26.07.2026\nA234V",
            lines: ["26.07.2026", "A234V"]
        )
        XCTAssertEqual(lot, "A234V")
    }

    func testJarLidStampLotAndMonthYear() throws {
        let result = interpreter.interpret(lines: ["J11LR233 12/2028 L1"])
        XCTAssertEqual(result.lotto, "J11LR233")
        XCTAssertNotEqual(result.lotto, "L1")
        let date = try XCTUnwrap(result.scadenza)
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: date)
        XCTAssertEqual(comps.month, 12)
        XCTAssertEqual(comps.year, 2028)
        let last = Calendar.current.range(of: .day, in: .month, for: date)?.count
        XCTAssertEqual(comps.day, last)
    }

    func testEggPackParentheticalLot() throws {
        let result = interpreter.interpret(lines: [
            "Lotto",
            "(Z) Z63648",
            "Da consumarsi preferibilmente entro il",
            "17/07/26"
        ])
        XCTAssertEqual(result.lotto, "(Z)Z63648")
        assertDate(try XCTUnwrap(result.scadenza), day: 17, month: 7, year: 2026)
    }

    func testTimeGluedLotRejectsPackagingNoise() throws {
        let result = interpreter.interpret(lines: [
            "NON VENDIBILE SINGOLARMENTE",
            "DA CONSUMARSI PREFERIBILMENTE ENTRO",
            "28/08/26",
            "08:14F0602 67661"
        ])
        XCTAssertEqual(result.lotto, "F060267661")
        XCTAssertFalse(result.lotto?.contains("VENDIBILE") == true)
        assertDate(try XCTUnwrap(result.scadenza), day: 28, month: 8, year: 2026)
    }

    func testCombinedItalianLabel() throws {
        let result = interpreter.interpret(lines: [
            "Da consumarsi preferibilmente entro il:",
            "26.07.2026",
            "L. 26F082/B"
        ])
        XCTAssertEqual(result.lotto, "L.26F082/B")
        assertDate(try XCTUnwrap(result.scadenza), day: 26, month: 7, year: 2026)
    }

    // MARK: - Helpers

    private func assertExpiry(_ text: String, day: Int, month: Int, year: Int) {
        let result = interpreter.extractExpiry(from: text)
        XCTAssertNotNil(result.date, "Expected expiry for \(text)")
        guard let date = result.date else { return }
        assertDate(date, day: day, month: month, year: year)
    }

    private func assertExpiryMonthEnd(_ text: String, month: Int, year: Int) {
        let result = interpreter.extractExpiry(from: text)
        XCTAssertNotNil(result.date, "Expected month-end expiry for \(text)")
        guard let date = result.date else { return }
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: date)
        XCTAssertEqual(comps.month, month, text)
        XCTAssertEqual(comps.year, year, text)
        let lastDay = Calendar.current.range(of: .day, in: .month, for: date)?.count
        XCTAssertEqual(comps.day, lastDay, text)
    }

    private func assertDate(_ date: Date, day: Int, month: Int, year: Int) {
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: date)
        XCTAssertEqual(comps.day, day)
        XCTAssertEqual(comps.month, month)
        XCTAssertEqual(comps.year, year)
    }
}
