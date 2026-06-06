@testable import ChronoCore
import XCTest

final class CoreModelTests: XCTestCase {
    func testJulianDayNumberRoundTripsAcrossWideRange() throws {
        // Walk every day across two centuries and confirm JDN round-trips.
        let start = try XCTUnwrap(GregorianDay(year: 1800, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2200, month: 12, day: 31))
        var jdn = start.julianDayNumber
        var previous = jdn - 1
        while jdn <= end.julianDayNumber {
            let day = GregorianDay(julianDayNumber: jdn)
            XCTAssertEqual(day.julianDayNumber, jdn)
            XCTAssertEqual(jdn, previous + 1, "JDN must be contiguous and monotonic")
            previous = jdn
            jdn += 1
        }
    }

    func testKnownJulianDayNumbers() {
        // 2000-01-01 is JDN 2451545 (noon-based integer convention).
        XCTAssertEqual(GregorianDay(year: 2000, month: 1, day: 1)?.julianDayNumber, 2451545)
        XCTAssertEqual(GregorianDay(year: 1970, month: 1, day: 1)?.julianDayNumber, 2440588)
    }

    func testDayArithmetic() throws {
        let day = try XCTUnwrap(GregorianDay(year: 2024, month: 2, day: 28))
        XCTAssertEqual(day.adding(days: 1), GregorianDay(year: 2024, month: 2, day: 29))
        XCTAssertEqual(day.adding(days: 2), GregorianDay(year: 2024, month: 3, day: 1))
        XCTAssertEqual(try GregorianDay(year: 2025, month: 1, day: 1)?.days(since: XCTUnwrap(GregorianDay(year: 2024, month: 1, day: 1))), 366)
    }

    func testFingerprintIsDeterministicAndSensitive() {
        let spec = CalendarDateSpec(
            system: .hebrew, variant: .hebrewCivil, year: 5785, month: 1, day: 1,
            dayBoundary: .sunset(bornAfterSunset: true)
        )
        let a = CalendarComputationFingerprint(engineVersion: "1.0", spec: spec, providerDataVersion: "p1")
        let b = CalendarComputationFingerprint(engineVersion: "1.0", spec: spec, providerDataVersion: "p1")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.cacheKey, b.cacheKey)

        var other = spec
        other.dayBoundary = .sunset(bornAfterSunset: false)
        let c = CalendarComputationFingerprint(engineVersion: "1.0", spec: other, providerDataVersion: "p1")
        XCTAssertNotEqual(a.boundaryHash, c.boundaryHash)

        let d = CalendarComputationFingerprint(engineVersion: "1.0", spec: spec, providerDataVersion: "p2")
        XCTAssertNotEqual(a.cacheKey, d.cacheKey)
    }

    func testRegistryDefaultAndRegistration() {
        let registry = CalendarEngineRegistry()
        XCTAssertNotNil(registry.engine(for: .gregorian))
        XCTAssertNil(registry.engine(for: .hebrew))
        XCTAssertEqual(registry.registeredSystems, [.gregorian])
        XCTAssertEqual(registry.capabilities().first?.system, .gregorian)
    }

    func testSpecCodableRoundTripWithEra() throws {
        let spec = CalendarDateSpec(
            system: .indianPanchanga, variant: .indianPanchangaDefault, era: "kali",
            year: 5125, month: 3, day: 11, isLeapMonth: true,
            dayBoundary: .sunrise,
            recurrencePolicy: .exactMonthDay,
            calculationLocation: CalculationLocation(identifier: "delhi", latitude: 28.6139, longitude: 77.2090, timeZoneIdentifier: "Asia/Kolkata")
        )
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(CalendarDateSpec.self, from: data)
        XCTAssertEqual(spec, decoded)
    }

    func testDayBoundaryCodableForms() throws {
        let boundaries: [DayBoundary] = [
            .engineDefault, .sunrise,
            .civilMidnight(timeZoneIdentifier: "Asia/Seoul"),
            .sunset(bornAfterSunset: true), .sunset(bornAfterSunset: nil)
        ]
        for boundary in boundaries {
            let data = try JSONEncoder().encode(boundary)
            XCTAssertEqual(try JSONDecoder().decode(DayBoundary.self, from: data), boundary)
        }
    }

    func testCapabilityCodableRoundTrip() throws {
        let cap = GregorianEngine().capability
        let data = try JSONEncoder().encode(cap)
        XCTAssertEqual(try JSONDecoder().decode(CalendarSystemCapability.self, from: data), cap)
        XCTAssertEqual(cap.supportedGregorianRange?.lowerBound, GregorianDay(year: 1600, month: 1, day: 1))
    }
}
