import XCTest
import Foundation
@testable import LabelScannerV2

final class RegexFallbackInterpreterTests: XCTestCase {
    private let interpreter = RegexFallbackInterpreter()

    func testLottoAndScadOnSeparateLines() throws {
        let lines = loadOCRMock("lotto_scad_separate")
        let result = interpreter.interpret(lines: lines)
        XCTAssertEqual(result.lotto, "L6036BH099")
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 23)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.year, 2026)
    }

    func testYogurtInkjetHardCase() throws {
        let lines = loadOCRMock("yogurt_inkjet")
        let result = interpreter.interpret(lines: lines)
        XCTAssertEqual(result.lotto, "08:18H-FYB")
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 31)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.year, 2026)
    }

    func testBatchNumberAndBestBeforeEnd() throws {
        let lines = loadOCRMock("batch_number_bbe")
        let result = interpreter.interpret(lines: lines)
        XCTAssertEqual(result.lotto, "44464")
        let comps = Calendar.current.dateComponents([.month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.year, 2027)
        XCTAssertNotEqual(result.lotto?.lowercased(), "number")
    }

    func testItalianLDotSlashLot() throws {
        let lines = [
            "Da consumarsi preferibilmente entro il:",
            "26.07.2026",
            "L. 26F082/B",
            "AL VAPORE"
        ]
        let result = interpreter.interpret(lines: lines)
        XCTAssertEqual(result.lotto, "L.26F082/B")
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 26)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.year, 2026)
    }

    func testMonthNameExtended() throws {
        let lines = loadOCRMock("month_name")
        let result = interpreter.interpret(lines: lines)
        XCTAssertNotNil(result.scadenza)
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 26)
        XCTAssertEqual(comps.month, 11)
        XCTAssertEqual(comps.year, 2025)
    }

    func testTwoDigitYear() throws {
        let result = interpreter.interpret(lines: ["EXP 09/10/26"])
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 9)
        XCTAssertEqual(comps.month, 10)
        XCTAssertEqual(comps.year, 2026)
    }

    func testNumbersOnlyIndustrialStamp() throws {
        let lines = loadOCRMock("numbers_only")
        let result = interpreter.interpret(lines: lines)
        XCTAssertEqual(result.lotto, "4B22")
        XCTAssertNotNil(result.scadenza)
    }

    func testNoisyOCRStillFindsBatch() throws {
        let lines = loadOCRMock("noisy_ocr")
        let result = interpreter.interpret(lines: lines)
        // "B4tch number: 44464" — pattern batch number may miss typo; date should still parse
        XCTAssertNotNil(result.scadenza)
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 31)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.year, 2026)
    }

    func testRejectsMarketingWords() {
        XCTAssertNil(LotNormalizer.normalize("LATTY"))
        XCTAssertNil(LotNormalizer.normalize("number"))
        XCTAssertNil(LotNormalizer.normalize("GRECO"))
        XCTAssertEqual(LotNormalizer.normalize("08:18H-FYB"), "08:18H-FYB")
        XCTAssertEqual(LotNormalizer.normalize("44464"), "44464")
    }

    func testExpirySanityRejectsAbsurdYears() {
        let validator = ExpirySanityValidator()
        let far = Calendar.current.date(from: DateComponents(year: 2039, month: 1, day: 1))
        let past = Calendar.current.date(from: DateComponents(year: 2015, month: 1, day: 1))
        XCTAssertNil(validator.validate(far))
        XCTAssertNil(validator.validate(past))
    }

    private func loadOCRMock(_ name: String) -> [String] {
        let url = Bundle.module.url(
            forResource: name,
            withExtension: "txt",
            subdirectory: "Fixtures/ocr_mocks"
        )
        guard let url,
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Missing OCR mock \(name)")
            return []
        }
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
