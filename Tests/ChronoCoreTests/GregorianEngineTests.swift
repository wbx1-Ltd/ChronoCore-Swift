@testable import ChronoCore
import XCTest

final class GregorianEngineTests: XCTestCase {
    func testReturnsOneOccurrenceForYearlessGregorianBirthday() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: nil,
            month: 3,
            day: 14
        )

        let occurrences = try engine.occurrences(of: spec, inGregorianYear: 2026)

        XCTAssertEqual(occurrences.map(\.day), [
            GregorianDay(year: 2026, month: 3, day: 14)
        ])
        XCTAssertEqual(occurrences.first?.provider, .algorithmic)
        XCTAssertEqual(occurrences.first?.sourceSpec, spec)
    }

    func testYearfulGregorianSpecOnlyEmitsInItsOwnYear() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: 2026,
            month: 3,
            day: 14
        )

        XCTAssertEqual(
            try engine.occurrences(of: spec, inGregorianYear: 2026).map(\.day),
            [GregorianDay(year: 2026, month: 3, day: 14)]
        )
        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2025), [])
    }

    func testEngineDefaultSkipsYearlessLeapDayInNonLeapYears() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: nil,
            month: 2,
            day: 29
        )

        XCTAssertEqual(
            try engine.occurrences(of: spec, inGregorianYear: 2024).map(\.day),
            [GregorianDay(year: 2024, month: 2, day: 29)]
        )
        XCTAssertEqual(
            try engine.occurrences(of: spec, inGregorianYear: 2025).map(\.day),
            []
        )
    }

    func testNearestValidDayPolicyUsesFebruaryTwentyEightForLeapDayInNonLeapYears() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: nil,
            month: 2,
            day: 29,
            recurrencePolicy: .nearestValidDay
        )

        let occurrences = try engine.occurrences(of: spec, inGregorianYear: 2025)

        XCTAssertEqual(occurrences.map(\.day), [
            GregorianDay(year: 2025, month: 2, day: 28)
        ])
        XCTAssertEqual(occurrences.first?.notes, [.adjustedToNearestValidDay])
    }

    func testRejectsSpecForWrongCalendarSystem() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .hebrew,
            variant: .standard,
            year: nil,
            month: 3,
            day: 14
        )

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2026)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedSystem(.hebrew))
        }
    }

    func testRejectsUnsupportedVariant() {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .hebrewCivil,
            year: nil,
            month: 3,
            day: 14
        )

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2026)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.hebrewCivil))
        }
    }

    func testRejectsDatesOutsideSupportedRange() throws {
        let engine = GregorianEngine()
        let spec = CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: nil,
            month: 1,
            day: 1
        )

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 1500)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .outOfSupportedRange(system: .gregorian, year: 1500))
        }
        XCTAssertThrowsError(try engine.dateSpec(from: XCTUnwrap(GregorianDay(year: 2500, month: 1, day: 1)))) { error in
            XCTAssertEqual(error as? CalendarEngineError, .outOfSupportedRange(system: .gregorian, year: 2500))
        }
    }

    func testBuildsDateSpecFromGregorianDay() throws {
        let engine = GregorianEngine()
        let day = try XCTUnwrap(GregorianDay(year: 2026, month: 6, day: 3))

        let spec = try engine.dateSpec(from: day)

        XCTAssertEqual(spec.system, .gregorian)
        XCTAssertEqual(spec.variant, .standard)
        XCTAssertEqual(spec.year, 2026)
        XCTAssertEqual(spec.month, 6)
        XCTAssertEqual(spec.day, 3)
        XCTAssertEqual(spec.dayBoundary, .engineDefault)
    }
}
