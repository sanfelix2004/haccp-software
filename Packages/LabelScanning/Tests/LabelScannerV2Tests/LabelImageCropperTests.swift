import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import LabelScannerV2

final class LabelImageCropperTests: XCTestCase {
    func testMakeRetryCropsProducesNonEmptyJPEGs() throws {
        let source = try makeSolidJPEG(width: 400, height: 600)
        let crops = LabelImageCropper.makeRetryCrops(from: source)
        XCTAssertEqual(crops.count, LabelImageCropper.defaultRetryRegions.count)
        for crop in crops {
            XCTAssertFalse(crop.isEmpty)
            XCTAssertNotNil(CGImageSourceCreateWithData(crop as CFData, nil))
        }
    }

    func testTinyImageYieldsNoCrops() throws {
        let source = try makeSolidJPEG(width: 20, height: 20)
        XCTAssertTrue(LabelImageCropper.makeRetryCrops(from: source).isEmpty)
    }

    private func makeSolidJPEG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 200, count: height * bytesPerRow)
        let data = try XCTUnwrap(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ).flatMap { context -> Data? in
                guard let image = context.makeImage() else { return nil }
                let out = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(
                    out,
                    UTType.jpeg.identifier as CFString,
                    1,
                    nil
                ) else { return nil }
                CGImageDestinationAddImage(destination, image, nil)
                guard CGImageDestinationFinalize(destination) else { return nil }
                return out as Data
            }
        )
        return data
    }
}
