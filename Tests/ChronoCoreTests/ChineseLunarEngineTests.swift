import ChronoCore
import ChronoCoreLunarCoreAdapter
import ChronoCoreTesting
import Foundation
import XCTest

final class ChineseLunarEngineTests: XCTestCase {
    private let engine = ChineseLunarEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("chinese-lunar", engine: engine)
    }

    func testCapabilityRange() {
        let cap = engine.capability
        XCTAssertTrue(cap.isImplemented)
        XCTAssertTrue(cap.isValidated)
        XCTAssertEqual(cap.defaultProvider, .dependency)
        XCTAssertFalse(cap.requiresLocation)
    }

    func testRoundTripIsStableAcrossDecade() throws {
        let report = try RangeCheck.roundTrip(
            engine: engine,
            from: XCTUnwrap(GregorianDay(year: 2015, month: 1, day: 1)),
            to: XCTUnwrap(GregorianDay(year: 2025, month: 12, day: 31))
        )
        XCTAssertTrue(report.isClean, "round-trip failures: \(report.failures.prefix(5))")
        XCTAssertGreaterThan(report.checked, 4000)
    }

    func testYearfulSpecEmitsOnlyInItsGregorianYear() throws {
        // Lunar 2024/1/1 resolves to 2024-02-10 and appears in no other year.
        let spec = CalendarDateSpec(system: .chineseLunar, variant: .chineseMainland, year: 2024, month: 1, day: 1)
        XCTAssertEqual(
            try engine.occurrences(of: spec, inGregorianYear: 2024).map(\.day),
            [GregorianDay(year: 2024, month: 2, day: 10)]
        )
        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2025).map(\.day), [])
    }

    func testLeapMonthFallsBackToRegularByDefault() throws {
        // 2021 has no leap month 4; default policy falls back to the regular month 4.
        let spec = CalendarDateSpec(
            system: .chineseLunar, variant: .chineseMainland,
            year: nil, month: 4, day: 1, isLeapMonth: true
        )
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2021)
        XCTAssertEqual(occ.count, 1)
        XCTAssertEqual(occ.first?.notes, [.leapMonthFallbackToRegular])
    }

    func testDayClampedForShortMonth() throws {
        // Requesting day 30 in a lunar month that has only 29 days clamps and notes it.
        // Probe a known short month via dateSpec round-trip is complex; instead assert
        // the clamp note appears when day exceeds the month length somewhere in 2023.
        let spec = CalendarDateSpec(
            system: .chineseLunar, variant: .chineseMainland,
            year: 2023, month: 1, day: 30
        )
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2023)
        // Lunar 2023 month 1 has 29 days, so day 30 clamps to 29.
        XCTAssertEqual(occ.count, 1)
        XCTAssertEqual(occ.first?.notes, [.monthLengthClamped])
    }

    func testExactMonthDayDoesNotClampShortMonth() throws {
        let spec = CalendarDateSpec(
            system: .chineseLunar,
            variant: .chineseMainland,
            year: 2023,
            month: 1,
            day: 30,
            recurrencePolicy: .exactMonthDay
        )

        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2023), [])
    }

    func testRejectsWrongSystem() {
        let spec = CalendarDateSpec(system: .gregorian, variant: .standard, year: nil, month: 1, day: 1)
        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024))
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .chineseLunar, variant: .standard, year: nil, month: 1, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testYearfulSpecOutsideDependencyRangeThrows() {
        let spec = CalendarDateSpec(system: .chineseLunar, variant: .chineseMainland, year: 1800, month: 1, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .outOfSupportedRange(system: .chineseLunar, year: 1800))
        }
    }

    /// Cross-provider sanity: ChronoCore (LunarCore) matches Foundation .chinese for
    /// a sample of dates. Foundation is a sanity oracle, not the truth.
    func testParityWithFoundationChineseSample() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))

        var day = try XCTUnwrap(GregorianDay(year: 2020, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2020, month: 12, day: 31))
        var mismatches = 0
        while day <= end {
            let spec = try engine.dateSpec(from: day)
            let date = try XCTUnwrap(gregorian.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)))
            let dc = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
            if dc.month != spec.month || dc.day != spec.day || (dc.isLeapMonth ?? false) != (spec.isLeapMonth ?? false) {
                mismatches += 1
            }
            day = day.adding(days: 1)
        }
        XCTAssertEqual(mismatches, 0, "ChronoCore Chinese disagreed with Foundation .chinese on \(mismatches) days in 2020")
    }
}
