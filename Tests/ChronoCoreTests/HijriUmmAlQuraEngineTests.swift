import ChronoCore
import ChronoCoreFoundation
import ChronoCoreTesting
import Foundation
import XCTest

final class HijriUmmAlQuraEngineTests: XCTestCase {
    private let engine = HijriUmmAlQuraEngine()

    func testGoldenFixtures() throws {
        try FixtureHarness.assertAll("hijri-umm-al-qura", engine: engine)
    }

    func testDoubleOccurrenceInOneGregorianYear() throws {
        let spec = CalendarDateSpec(system: .hijriUmmAlQura, variant: .ummAlQuraSaudi, year: nil, month: 1, day: 1)
        let days = try engine.occurrences(of: spec, inGregorianYear: 2008).map(\.day)
        XCTAssertEqual(days, [
            GregorianDay(year: 2008, month: 1, day: 10),
            GregorianDay(year: 2008, month: 12, day: 29)
        ])
    }

    func testYearfulSpecAppearsOnce() throws {
        let spec = CalendarDateSpec(system: .hijriUmmAlQura, variant: .ummAlQuraSaudi, year: 1446, month: 1, day: 1)
        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2024).map(\.day), [GregorianDay(year: 2024, month: 7, day: 7)])
        XCTAssertEqual(try engine.occurrences(of: spec, inGregorianYear: 2025).map(\.day), [])
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .hijriUmmAlQura, variant: .standard, year: nil, month: 1, day: 1)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testDateSpecRoundTrip() throws {
        var day = try XCTUnwrap(GregorianDay(year: 2024, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2024, month: 12, day: 31))
        while day <= end {
            let spec = try engine.dateSpec(from: day)
            let back = try engine.occurrences(of: spec, inGregorianYear: day.year).map(\.day)
            XCTAssertTrue(back.contains(day), "round-trip failed for \(day)")
            day = day.adding(days: 1)
        }
    }

    func testParityWithFoundationSample() throws {
        // The engine is Foundation-backed, so dateSpec must agree with ICU directly.
        var hij = Calendar(identifier: .islamicUmmAlQura)
        hij.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var day = try XCTUnwrap(GregorianDay(year: 2000, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2000, month: 12, day: 31))
        while day <= end {
            let spec = try engine.dateSpec(from: day)
            let date = try XCTUnwrap(greg.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)))
            let dc = hij.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual(spec.year, dc.year)
            XCTAssertEqual(spec.month, dc.month)
            XCTAssertEqual(spec.day, dc.day)
            day = day.adding(days: 1)
        }
    }

    func testCapability() {
        XCTAssertEqual(engine.capability.defaultProvider, .foundation)
        XCTAssertEqual(engine.capability.supportedVariants, [.ummAlQuraSaudi])
    }
}
