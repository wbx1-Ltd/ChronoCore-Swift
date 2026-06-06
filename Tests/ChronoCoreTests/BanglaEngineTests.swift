import ChronoCore
import ChronoCoreTables
import ChronoCoreTesting
import Foundation
import XCTest

final class BanglaEngineTests: XCTestCase {
    private let engine = BanglaEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("bangla", engine: engine)
    }

    func testPohelaBoishakhAlwaysApril14() throws {
        for banglaYear in 1390...1450 {
            let spec = CalendarDateSpec(system: .bangla, variant: .bangladeshRevised, year: banglaYear, month: 1, day: 1)
            let gregYear = banglaYear + 593
            let occ = try engine.occurrences(of: spec, inGregorianYear: gregYear)
            XCTAssertEqual(occ.map(\.day), [GregorianDay(year: gregYear, month: 4, day: 14)], "Pohela Boishakh \(banglaYear)")
        }
    }

    func testYearlessRecurrenceIncludesEarlyGregorianYearBanglaDates() throws {
        let spec = CalendarDateSpec(
            system: .bangla,
            variant: .bangladeshRevised,
            year: nil,
            month: 12,
            day: 12
        )

        XCTAssertEqual(
            try engine.occurrences(of: spec, inGregorianYear: 2023).map(\.day),
            [GregorianDay(year: 2023, month: 3, day: 26)]
        )
    }

    func testFalgunLeapBehaviour() throws {
        // 1426 (Gregorian 2020 leap) has Falgun 30; 1429 (2023 non-leap) does not.
        let leapSpec = CalendarDateSpec(system: .bangla, variant: .bangladeshRevised, year: 1426, month: 11, day: 30)
        let leapOcc = try engine.occurrences(of: leapSpec, inGregorianYear: 2020)
        XCTAssertEqual(leapOcc.count, 1)
        XCTAssertFalse(leapOcc.first?.notes.contains(.monthLengthClamped) ?? true)

        let nonLeapSpec = CalendarDateSpec(system: .bangla, variant: .bangladeshRevised, year: 1429, month: 11, day: 30)
        let nonLeapOcc = try engine.occurrences(of: nonLeapSpec, inGregorianYear: 2023)
        XCTAssertEqual(nonLeapOcc.count, 1)
        XCTAssertTrue(nonLeapOcc.first?.notes.contains(.monthLengthClamped) ?? false)
    }

    func testExactMonthDayDoesNotClampInvalidDate() throws {
        let spec = CalendarDateSpec(
            system: .bangla,
            variant: .bangladeshRevised,
            year: 1429,
            month: 11,
            day: 30,
            recurrencePolicy: .exactMonthDay
        )

        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2023), [])
    }

    func testYearLengthFollowsGregorianLeap() throws {
        // Days from one Pohela Boishakh to the next must be 365 or 366.
        for banglaYear in 1420...1440 {
            let start = try XCTUnwrap(engine.occurrences(of: spec(banglaYear, 1, 1), inGregorianYear: banglaYear + 593).first?.day)
            let next = try XCTUnwrap(engine.occurrences(of: spec(banglaYear + 1, 1, 1), inGregorianYear: banglaYear + 594).first?.day)
            let length = next.days(since: start)
            let expectedLeap = GregorianDay.isLeapYear(banglaYear + 594)
            XCTAssertEqual(length, expectedLeap ? 366 : 365, "Bangla \(banglaYear) length")
        }
    }

    func testReformBoundaryNote() throws {
        // Post-reform dates carry no historical note; pre-reform dates do.
        let post = try engine.dateSpec(from: XCTUnwrap(GregorianDay(year: 2024, month: 4, day: 14)))
        XCTAssertEqual(post.year, 1431)
        let postOcc = try engine.occurrences(of: post, inGregorianYear: 2024)
        XCTAssertFalse(postOcc.first?.notes.contains(.historicalRuleVersion) ?? true)

        let preOcc = try engine.occurrences(of: spec(1420, 1, 1), inGregorianYear: 2013)
        XCTAssertTrue(preOcc.first?.notes.contains(.historicalRuleVersion) ?? false)
    }

    func testDivergesFromFoundationTraditionalBangla() throws {
        // ICU .bangla is the traditional calendar; its New Year differs from the
        // Bangladesh revised April 14 Pohela Boishakh. Documented as a cross-check.
        guard #available(macOS 26, *) else { throw XCTSkip("needs OS 26") }
        let revisedNewYear = try XCTUnwrap(GregorianDay(year: 2019, month: 4, day: 14))
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Dhaka"))
        var bangla = Calendar(identifier: .bangla)
        bangla.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Dhaka"))
        let date = try XCTUnwrap(greg.date(from: DateComponents(year: 2019, month: 4, day: 14, hour: 12)))
        let dc = bangla.dateComponents([.month, .day], from: date)
        // Revised: this is Boishakh 1; traditional ICU: still end of the prior year.
        let revisedSpec = try engine.dateSpec(from: revisedNewYear)
        XCTAssertEqual(revisedSpec.month, 1)
        XCTAssertEqual(revisedSpec.day, 1)
        XCTAssertFalse(dc.month == 1 && dc.day == 1, "ICU traditional bangla should differ from revised at the New Year boundary")
    }

    func testFullRangeRoundTrip() throws {
        let report = try RangeCheck.roundTrip(
            engine: engine,
            from: XCTUnwrap(GregorianDay(year: 1950, month: 1, day: 1)),
            to: XCTUnwrap(GregorianDay(year: 2100, month: 12, day: 31))
        )
        XCTAssertTrue(report.isClean, "round-trip failures: \(report.failures.prefix(5))")
        XCTAssertGreaterThan(report.checked, 50000)
    }

    func testUnsupportedVariantThrows() {
        let s = CalendarDateSpec(system: .bangla, variant: .westBengalTraditional, year: 1430, month: 1, day: 1)
        XCTAssertThrowsError(try engine.occurrences(of: s, inGregorianYear: 2023)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.westBengalTraditional))
        }
    }

    func testCapability() {
        let cap = engine.capability
        XCTAssertEqual(cap.defaultProvider, .table)
        XCTAssertEqual(cap.supportedVariants, [.bangladeshRevised])
    }

    private func spec(_ year: Int, _ month: Int, _ day: Int) -> CalendarDateSpec {
        CalendarDateSpec(system: .bangla, variant: .bangladeshRevised, year: year, month: month, day: day)
    }
}
