import ChronoCore
import ChronoCoreAstronomy
import ChronoCoreTesting
import Foundation
import XCTest

final class KoreanLunisolarEngineTests: XCTestCase {
    private let engine = KoreanLunisolarEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("korean-lunisolar", engine: engine)
    }

    func testParityWithFoundationDangi() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else {
            throw XCTSkip("Foundation .dangi requires OS 26+")
        }
        // Clean modern range. Documented divergences (early 1900s Korean local
        // mean time era, and far-future ICU extrapolation 2074/2097) are excluded.
        LunisolarParity.assert(
            engine: engine,
            identifier: .dangi,
            timeZone: "Asia/Seoul",
            years: [1960, 1985, 2000, 2010, 2020, 2023, 2033, 2050]
        )
    }

    func testRoundTripStable() throws {
        let report = try RangeCheck.roundTrip(
            engine: engine,
            from: XCTUnwrap(GregorianDay(year: 2023, month: 1, day: 1)),
            to: XCTUnwrap(GregorianDay(year: 2024, month: 12, day: 31))
        )
        XCTAssertTrue(report.isClean, "failures: \(report.failures.prefix(5))")
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .koreanLunisolar, variant: .standard, year: nil, month: 1, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testCapability() {
        let cap = engine.capability
        XCTAssertEqual(cap.defaultProvider, .astronomy)
        XCTAssertTrue(cap.isHeavy)
        XCTAssertEqual(cap.supportedVariants, [.koreanModern])
    }
}
