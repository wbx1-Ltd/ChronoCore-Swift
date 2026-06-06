import ChronoCore
import ChronoCoreAstronomy
import ChronoCoreTesting
import Foundation
import XCTest

final class VietnameseLunisolarEngineTests: XCTestCase {
    private let engine = VietnameseLunisolarEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("vietnamese-lunisolar", engine: engine)
    }

    /// Clean modern range where high-precision UTC+7 astronomy matches the
    /// official calendar encoded by Foundation .vietnamese. Documented divergence
    /// years (1984, 1985, 2054, 2077, 2085) are excluded and covered separately.
    func testParityWithFoundationVietnamese() throws {
        guard #available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *) else {
            throw XCTSkip("Foundation .vietnamese requires OS 26+")
        }
        LunisolarParity.assert(
            engine: engine,
            identifier: .vietnamese,
            timeZone: "Asia/Ho_Chi_Minh",
            years: [1970, 1990, 2000, 2012, 2020, 2024, 2033, 2050]
        )
    }

    /// The documented 1985 divergence: ChronoCore canonical (astronomy) differs
    /// from Foundation .vietnamese (official almanac override).
    func testKnownDivergence1985() throws {
        let spec = CalendarDateSpec(system: .vietnameseLunisolar, variant: .vietnameseModernUTC7, year: nil, month: 1, day: 1)
        let canonical = try engine.occurrences(of: spec, inGregorianYear: 1985).map(\.day)
        XCTAssertEqual(canonical, [GregorianDay(year: 1985, month: 1, day: 21)])

        guard #available(macOS 26, *) else { return }
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        var viet = Calendar(identifier: .vietnamese)
        viet.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        let officialTet = try XCTUnwrap(greg.date(from: DateComponents(year: 1985, month: 2, day: 20, hour: 12)))
        let dc = viet.dateComponents([.month, .day], from: officialTet)
        XCTAssertEqual(dc.month, 1)
        XCTAssertEqual(dc.day, 1, "Foundation .vietnamese official Tet 1985 is 1985-02-20")
    }

    func testOutOfRangeBeforeReform() {
        let spec = CalendarDateSpec(system: .vietnameseLunisolar, variant: .vietnameseModernUTC7, year: nil, month: 1, day: 1)
        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 1950)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .outOfSupportedRange(system: .vietnameseLunisolar, year: 1950))
        }
    }

    func testRoundTripStable() throws {
        let report = try RangeCheck.roundTrip(
            engine: engine,
            from: XCTUnwrap(GregorianDay(year: 2023, month: 1, day: 1)),
            to: XCTUnwrap(GregorianDay(year: 2024, month: 12, day: 31))
        )
        XCTAssertTrue(report.isClean, "failures: \(report.failures.prefix(5))")
    }

    func testCapability() {
        XCTAssertEqual(engine.capability.defaultProvider, .astronomy)
        XCTAssertEqual(engine.capability.supportedVariants, [.vietnameseModernUTC7])
        XCTAssertEqual(engine.capability.supportedGregorianRange?.lowerBound, GregorianDay(year: 1968, month: 1, day: 1))
    }
}
