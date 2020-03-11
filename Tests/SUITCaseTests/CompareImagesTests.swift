/*
 SUITCase

 Copyright (c) 2020 Devexperts LLC

 See https://code.devexperts.com for more open source projects
*/

import XCTest
@testable import SUITCase

@available(iOS 12.0, *)
class CompareImagesTests: XCTestCase {
    func assertComparison(method: SUITCase.ScreenshotComparisonMethod,
                          _ image1: RGBAImage,
                          _ image2: RGBAImage,
                          expectedDifference: (image: RGBAImage, value: Double),
                          file: StaticString = #file,
                          line: UInt = #line) {
        do {
            let actualDifference = try SUITCase().compareImages(withMethod: method,
                                                                actual: image1,
                                                                reference: image2)
            XCTAssertEqual(actualDifference.image,
                           expectedDifference.image,
                           file: file,
                           line: line)
            XCTAssertEqual(actualDifference.value,
                           expectedDifference.value,
                           accuracy: 1e-6,
                           file: file,
                           line: line)
        } catch {
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }

    func assertComparisonError(method: SUITCase.ScreenshotComparisonMethod,
                               _ image1: RGBAImage,
                               _ image2: RGBAImage,
                               _ expectedError: Error,
                               file: StaticString = #file,
                               line: UInt = #line) {
        XCTAssertThrowsError(try SUITCase().compareImages(withMethod: method,
                                                          actual: image1,
                                                          reference: image2),
                             file: file,
                             line: line) { error in
            do {
                XCTAssertEqual(error.localizedDescription,
                               expectedError.localizedDescription,
                               "Unexpected error description",
                               file: file,
                               line: line)
            }
        }
    }

    let rgbaImage = RGBAImage(pixels: [.black, .blue, .green, .cyan,
                                       .red, .magenta, .yellow, .white,
                                       .darkGray, .gray, .lightGray, .clear],
                              width: 4,
                              height: 3)

    var lighterImage: RGBAImage {
        var template = rgbaImage

        func add16(_ component: inout UInt8) {
            component = component > 239 ? 255 : component + 16
        }

        for counter in 0..<template.pixels.count {
            add16(&template.pixels[counter].red)
            add16(&template.pixels[counter].green)
            add16(&template.pixels[counter].blue)
        }

        return template
    }

    func testStrictComparison() {
        assertComparison(method: .strict,
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: [.black, .black, .black, .black,
                                                                 .black, .black, .black, .white,
                                                                 .black, .black, .black, .clear],
                                                        width: 4,
                                                        height: 3),
                                              10 / 11))
    }

    func testWithToleranceComparison() {
        assertComparison(method: .withTolerance(tolerance: 0.05),
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: [.black, .black, .white, .white,
                                                                 .black, .white, .white, .white,
                                                                 .black, .black, .black, .clear],
                                                        width: 4,
                                                        height: 3),
                                              6 / 11))
        assertComparison(method: .withTolerance(tolerance: 0.06),
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: [.black, .white, .white, .white,
                                                                 .white, .white, .white, .white,
                                                                 .black, .black, .black, .clear],
                                                        width: 4,
                                                        height: 3),
                                              4 / 11))
    }

    let rgbwImage = RGBAImage(pixels: [.red, .green,
                                       .blue, .white],
                              width: 2,
                              height: 2)

    let cmykImage = RGBAImage(pixels: [.magenta, .cyan,
                                       .black, .yellow],
                              width: 2,
                              height: 2)

    func testGreyscaleComparison() {
        assertComparison(method: .greyscale(tolerance: 0.1),
                         rgbwImage,
                         cmykImage,
                         expectedDifference: (RGBAImage(pixels: [.white, .white,
                                                                 .black, .white],
                                                        width: 2,
                                                        height: 2),
                                              1 / 4))
        assertComparison(method: .greyscale(tolerance: 0.3),
                         rgbwImage,
                         cmykImage,
                         expectedDifference: (RGBAImage(pixels: [.white, .white,
                                                                 .white, .white],
                                                        width: 2,
                                                        height: 2),
                                              0 / 4))
    }

    func testAverageColorComparison() {
        let width = 100

        assertComparison(method: .averageColor,
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: Array(repeating: RGBAPixel.gray,
                                                                      count: width * width)
                                                                + Array(repeating: RGBAPixel(white: 138),
                                                                        count: width * width),
                                                        width: width,
                                                        height: 2 * width),
                                              0.039216))
        assertComparison(method: .averageColor,
                         rgbwImage,
                         cmykImage,
                         expectedDifference: (RGBAImage(pixels: Array(repeating: RGBAPixel.gray,
                                                                      count: 2 * width * width),
                                                        width: width,
                                                        height: 2 * width),
                                              0))
    }

    func testDnaComparison() {
        assertComparison(method: .dna(tolerance: 0.03),
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: [.black, .black, .black, .white,
                                                                 .black, .black, .white, .white,
                                                                 .black, .black, .black, .clear],
                                                        width: 4,
                                                        height: 3),
                                              8 / 11))
        assertComparison(method: .dna(tolerance: 0.02),
                         rgbaImage,
                         lighterImage,
                         expectedDifference: (RGBAImage(pixels: [.black, .black, .black, .black,
                                                                 .black, .black, .black, .white,
                                                                 .black, .black, .black, .clear],
                                                        width: 4,
                                                        height: 3),
                                              10 / 11))
    }

    func testThrowingErrors() {
        let leftTransparentImage = RGBAImage(pixels: [.clear, .black,
                                                      .clear, .brown],
                                             width: 2,
                                             height: 2)
        let rightTransparentImage = RGBAImage(pixels: [.green, .clear,
                                                       .magenta, .clear],
                                              width: 2,
                                              height: 2)
        assertComparisonError(method: .strict,
                              leftTransparentImage,
                              rightTransparentImage,
                              SUITCase.VerifyScreenshotError.nothingCommon)
        assertComparisonError(method: .greyscale(tolerance: 0.01),
                              leftTransparentImage,
                              rgbaImage,
                              SUITCase.VerifyScreenshotError.unexpectedSize)
        let fullyTransparentImage = RGBAImage(pixel: .clear, width: 5, height: 6)
        assertComparisonError(method: .averageColor,
                              fullyTransparentImage,
                              rightTransparentImage,
                              SUITCase.VerifyScreenshotError.nothingCommon)
    }

    static var allTests = [
        ("testStrictComparison", testStrictComparison),
        ("testWithToleranceComparison", testWithToleranceComparison),
        ("testGreyscaleComparison", testGreyscaleComparison),
        ("testAverageColorComparison", testAverageColorComparison),
        ("testDnaComparison", testDnaComparison),
        ("testThrowingErrors", testThrowingErrors)
    ]
}