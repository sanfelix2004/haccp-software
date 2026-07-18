import XCTest
import Foundation
@testable import LabelScannerV2
import LabelScanningContract

final class LabelScannerV2EngineTests: XCTestCase {
    func testInterpretOCRLinesUsesRegexWhenFoundationModelsUnavailable() async {
        let engine = LabelScannerV2Engine(
            semanticInterpreter: UnavailableSemanticInterpreter()
        )
        let result = await engine.interpretOCRLines([
            "Best Before End: 11/2027",
            "Batch number: 44464"
        ])
        XCTAssertEqual(result.lotto, "44464")
        XCTAssertNotNil(result.scadenza)
        XCTAssertTrue(result.needsManualConfirmation)
        // Senza Foundation Models la confidenza resta sul path regex (può essere alta se lotto+scadenza ok)
    }

    func testYogurtOCRLines() async {
        let engine = LabelScannerV2Engine(
            semanticInterpreter: UnavailableSemanticInterpreter()
        )
        let result = await engine.interpretOCRLines([
            "YOGURT GRECO",
            "31/08/26",
            "08:18H-FYB",
            "LATTY"
        ])
        XCTAssertEqual(result.lotto, "08:18H-FYB")
        let comps = Calendar.current.dateComponents([.day, .month, .year], from: try! XCTUnwrap(result.scadenza))
        XCTAssertEqual(comps.day, 31)
        XCTAssertEqual(comps.month, 8)
        XCTAssertEqual(comps.year, 2026)
    }

    func testImageFixtureYogurtEndToEndRegexPath() async throws {
        let engine = LabelScannerV2Engine(
            semanticInterpreter: UnavailableSemanticInterpreter()
        )
        let data = try loadImageFixture("yogurt_inkjet")
        let result = try await engine.scan(imageData: data)
        if let lotto = result.lotto {
            XCTAssertFalse(["LATTY", "LATTE", "NUMBER", "YOGURT"].contains(lotto.uppercased()))
        }
        XCTAssertFalse(result.rawRecognizedText.isEmpty)
    }

    func testImageFixtureBatchEndToEnd() async throws {
        let engine = LabelScannerV2Engine(
            semanticInterpreter: UnavailableSemanticInterpreter()
        )
        let data = try loadImageFixture("batch_number_bbe")
        let result = try await engine.scan(imageData: data)
        XCTAssertFalse(result.rawRecognizedText.isEmpty)
        if let lotto = result.lotto {
            XCTAssertNotEqual(lotto.lowercased(), "number")
        }
    }

    private func loadImageFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: name,
                withExtension: "png",
                subdirectory: "Fixtures/images"
            )
        )
        return try Data(contentsOf: url)
    }
}

private struct UnavailableSemanticInterpreter: LabelSemanticInterpreter {
    var isAvailable: Bool { false }

    func interpret(imageData: Data, ocrLines: [String]) async throws -> InterpretedLabelFields {
        throw InterpreterUnavailable.appleIntelligenceUnavailable
    }
}
