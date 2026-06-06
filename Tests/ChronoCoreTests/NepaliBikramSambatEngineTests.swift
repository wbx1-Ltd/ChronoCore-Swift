import ChronoCore
import ChronoCoreTables
import ChronoCoreTesting
import XCTest

final class NepaliBikramSambatEngineTests: XCTestCase {
    private let engine = NepaliBikramSambatEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("nepali-bikram-sambat", engine: engine)
    }

    func testNewYearAlwaysInAprilWindow() throws {
        // Every BS New Year (Baishakh 1) must fall on Gregorian April 12...15.
        for bsYear in 1970...2090 {
            let spec = CalendarDateSpec(system: .nepaliBikramSambat, variant: .nepaliOfficial, year: bsYear, month: 1, day: 1)
            let gregYear = bsYear - 57
            let occ = try engine.occurrences(of: spec, inGregorianYear: gregYear)
                + engine.occurrences(of: spec, inGregorianYear: gregYear + 1)
            let day = try XCTUnwrap(occ.first?.day, "no New Year for BS \(bsYear)")
            XCTAssertEqual(day.month, 4, "BS \(bsYear) New Year not in April: \(day)")
            XCTAssertTrue((12...15).contains(day.day), "BS \(bsYear) New Year day \(day.day) outside 12...15")
        }
    }

    func testFullRangeRoundTrip() throws {
        let report = try RangeCheck.roundTrip(
            engine: engine,
            from: XCTUnwrap(GregorianDay(year: 1914, month: 1, day: 1)),
            to: XCTUnwrap(GregorianDay(year: 2033, month: 12, day: 31))
        )
        XCTAssertTrue(report.isClean, "round-trip failures: \(report.failures.prefix(5))")
        XCTAssertGreaterThan(report.checked, 39000)
    }

    func testMonthLengthClamp() throws {
        // Day 32 in a 31-day BS month clamps to the last day with a note.
        let spec = CalendarDateSpec(system: .nepaliBikramSambat, variant: .nepaliOfficial, year: 2080, month: 1, day: 32)
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2023)
        XCTAssertEqual(occ.count, 1)
        XCTAssertTrue(occ.first?.notes.contains(.monthLengthClamped) ?? false)
    }

    func testExactMonthDayDoesNotClampInvalidDate() throws {
        let spec = CalendarDateSpec(
            system: .nepaliBikramSambat,
            variant: .nepaliOfficial,
            year: 2080,
            month: 1,
            day: 32,
            recurrencePolicy: .exactMonthDay
        )

        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2023), [])
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .nepaliBikramSambat, variant: .standard, year: 2080, month: 1, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2023)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testOutOfRange() throws {
        // BS 1960 is before the table start (1970); no occurrence is produced.
        let spec = CalendarDateSpec(system: .nepaliBikramSambat, variant: .nepaliOfficial, year: 1960, month: 1, day: 1)
        let occ = try? engine.occurrences(of: spec, inGregorianYear: 1903)
        XCTAssertEqual(occ, [])
        XCTAssertThrowsError(try engine.dateSpec(from: XCTUnwrap(GregorianDay(year: 1800, month: 1, day: 1))))
    }

    func testCapability() {
        let cap = engine.capability
        XCTAssertEqual(cap.defaultProvider, .table)
        XCTAssertEqual(cap.supportedVariants, [.nepaliOfficial])
        XCTAssertFalse(cap.requiresLocation)
    }
}
