import ChronoCore
import ChronoCoreFoundation
import ChronoCoreTesting
import Foundation
import XCTest

final class HebrewEngineTests: XCTestCase {
    private let engine = HebrewEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("hebrew", engine: engine)
    }

    func testStableMonthCodesRoundTrip() {
        for month in HebrewMonth.allCases {
            XCTAssertEqual(HebrewMonth(stableCode: month.stableCode), month)
        }
    }

    func testLeapYearDetection() {
        // 5784 is leap (year 8 of cycle); 5785 and 5783 are common.
        XCTAssertTrue(HebrewMonth.isLeapYear(5784))
        XCTAssertFalse(HebrewMonth.isLeapYear(5785))
        XCTAssertFalse(HebrewMonth.isLeapYear(5783))
    }

    func testPlainAdarMapsToAdarIIInLeapYearWithNote() throws {
        let spec = HebrewEngine.spec(year: nil, month: .adar, day: 14)
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2024)
        XCTAssertEqual(occ.map(\.day), [GregorianDay(year: 2024, month: 3, day: 24)])
        XCTAssertTrue(occ.first?.notes.contains(.adarMappedToAdarII) ?? false)
        XCTAssertTrue(occ.first?.notes.contains(.bornAfterSunsetUnspecified) ?? false)
    }

    func testAdarIInCommonYearMapsToAdarWithNote() throws {
        // adarI requested for a common Hebrew year 5785 (Gregorian 2025).
        let spec = HebrewEngine.spec(year: 5785, month: .adarI, day: 1)
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2025)
        XCTAssertEqual(occ.count, 1)
        XCTAssertTrue(occ.first?.notes.contains(.adarMappedToAdar) ?? false)
    }

    func testCheshvan30AbsentByDefaultButClampsUnderPolicy() throws {
        let absent = HebrewEngine.spec(year: 5784, month: .cheshvan, day: 30)
        XCTAssertEqual(try engine.occurrences(of: absent, inGregorianYear: 2023), [])

        let clamp = HebrewEngine.spec(year: 5784, month: .cheshvan, day: 30, recurrencePolicy: .nearestValidDay)
        let occ = try engine.occurrences(of: clamp, inGregorianYear: 2023)
        XCTAssertEqual(occ.map(\.day), [GregorianDay(year: 2023, month: 11, day: 13)])
        XCTAssertTrue(occ.first?.notes.contains(.monthLengthClamped) ?? false)
    }

    func testBornAfterSunsetNote() throws {
        let spec = HebrewEngine.spec(year: 5785, month: .tishrei, day: 1, bornAfterSunset: true)
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2024)
        XCTAssertEqual(occ.first?.day, GregorianDay(year: 2024, month: 10, day: 3))
        XCTAssertTrue(occ.first?.notes.contains(.dayAdvancedForSunset) ?? false)
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .hebrew, variant: .standard, year: nil, month: HebrewMonth.tishrei.stableCode, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testDateSpecRoundTrip() throws {
        // Gregorian -> Hebrew spec -> back to the same Gregorian day.
        var day = try XCTUnwrap(GregorianDay(year: 2024, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2024, month: 12, day: 31))
        while day <= end {
            let spec = try engine.dateSpec(from: day)
            let back = try engine.occurrences(of: spec, inGregorianYear: day.year).map(\.day)
            XCTAssertTrue(back.contains(day), "round-trip failed for \(day): got \(back)")
            day = day.adding(days: 1)
        }
    }

    func testCapability() {
        let cap = engine.capability
        XCTAssertEqual(cap.defaultProvider, .foundation)
        XCTAssertTrue(cap.isValidated)
    }
}
