import ChronoCore
import ChronoCoreAstronomy
import ChronoCoreTesting
import XCTest

final class IndianPanchangaEngineTests: XCTestCase {
    private let engine = IndianPanchangaEngine()
    private let ujjain = IndianPanchangaEngine.defaultLocation
    private let honolulu = CalculationLocation(identifier: "honolulu", latitude: 21.3069, longitude: -157.8583, timeZoneIdentifier: "Pacific/Honolulu")

    func testGoldenFestivalFixtures() throws {
        try FixtureHarness.assertAll("indian-panchanga", engine: engine)
    }

    /// Full five-limb panchang at sunrise, verified against Drik Panchang
    /// (drikpanchang.com, Lahiri ayanamsa, amanta month) across five Indian
    /// cities, both pakshas, full and new moon, and the amanta month junction.
    func testFullPanchangaAgainstDrikPanchang() throws {
        struct Reference {
            let city: String, lat: Double, lon: Double
            let year: Int, month: Int, day: Int
            let tithi: Int, paksha: Panchanga.Paksha, nakshatra: Int, yoga: Int, masa: Int, karana: String
        }
        let references = [
            Reference(city: "New Delhi", lat: 28.6139, lon: 77.2090, year: 2025, month: 1, day: 1,
                      tithi: 2, paksha: .shukla, nakshatra: 21, yoga: 13, masa: 10, karana: "Balava"),
            Reference(city: "Chennai", lat: 13.0827, lon: 80.2707, year: 2024, month: 8, day: 19,
                      tithi: 15, paksha: .shukla, nakshatra: 22, yoga: 5, masa: 5, karana: "Vishti"),
            Reference(city: "Mumbai", lat: 19.0760, lon: 72.8777, year: 2025, month: 3, day: 14,
                      tithi: 15, paksha: .shukla, nakshatra: 12, yoga: 9, masa: 12, karana: "Bava"),
            Reference(city: "Kolkata", lat: 22.5726, lon: 88.3639, year: 2024, month: 11, day: 1,
                      tithi: 30, paksha: .krishna, nakshatra: 15, yoga: 2, masa: 7, karana: "Naga"),
            Reference(city: "Bengaluru", lat: 12.9716, lon: 77.5946, year: 2024, month: 4, day: 9,
                      tithi: 1, paksha: .shukla, nakshatra: 27, yoga: 27, masa: 1, karana: "Kimstughna")
        ]
        for ref in references {
            let location = CalculationLocation(identifier: ref.city, latitude: ref.lat, longitude: ref.lon, timeZoneIdentifier: "Asia/Kolkata")
            let day = try XCTUnwrap(GregorianDay(year: ref.year, month: ref.month, day: ref.day))
            let p = try engine.panchanga(for: day, location: location)
            let context = "\(ref.city) \(day)"
            XCTAssertEqual(p.tithi, ref.tithi, "tithi \(context)")
            XCTAssertEqual(p.paksha, ref.paksha, "paksha \(context)")
            XCTAssertEqual(p.nakshatra, ref.nakshatra, "nakshatra \(context)")
            XCTAssertEqual(p.yoga, ref.yoga, "yoga \(context)")
            XCTAssertEqual(p.masa, ref.masa, "masa \(context)")
            XCTAssertEqual(Self.karanaName(p.karana), ref.karana, "karana \(context)")
        }
    }

    /// Karana name for the half-tithi index 1...60.
    private static func karanaName(_ k: Int) -> String {
        if k == 1 { return "Kimstughna" }
        if k >= 58 { return ["Shakuni", "Chatushpada", "Naga"][k - 58] }
        return ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"][(k - 2) % 7]
    }

    func testPurnimaIsFullMoonTithi() throws {
        // Vaishakha Purnima 2024 (Buddha Purnima) prevails at sunrise on May 23.
        let p = try engine.panchanga(for: XCTUnwrap(GregorianDay(year: 2024, month: 5, day: 23)), location: ujjain)
        XCTAssertEqual(p.tithi, 15)
        XCTAssertEqual(p.paksha, .shukla)
        XCTAssertEqual(p.masa, 2)
    }

    func testAmavasyaTithi() throws {
        let p = try engine.panchanga(for: XCTUnwrap(GregorianDay(year: 2024, month: 11, day: 1)), location: ujjain)
        XCTAssertEqual(p.tithi, 30)
        XCTAssertEqual(p.paksha, .krishna)
    }

    func testNakshatraOccurrencesAreReasonable() throws {
        // A nakshatra prevails at sunrise about 13 times per year.
        let occ = try engine.nakshatraOccurrences(nakshatra: 1, inGregorianYear: 2024, location: ujjain)
        XCTAssertTrue((11...14).contains(occ.count), "expected ~13 nakshatra days, got \(occ.count)")
        for o in occ {
            let p = try engine.panchanga(for: o.day, location: ujjain)
            XCTAssertEqual(p.nakshatra, 1)
        }
    }

    func testLocationSensitivityAcrossCities() throws {
        // Sunrise differs by many hours between Ujjain and Honolulu, so at least
        // some days have a different tithi at sunrise.
        var differing = 0
        var day = try XCTUnwrap(GregorianDay(year: 2024, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2024, month: 2, day: 15))
        while day <= end {
            let a = try engine.panchanga(for: day, location: ujjain)
            let b = try engine.panchanga(for: day, location: honolulu)
            if a.tithi != b.tithi { differing += 1 }
            day = day.adding(days: 1)
        }
        XCTAssertGreaterThan(differing, 0, "expected sunrise tithi to differ between distant cities")
    }

    func testRepeatedTithiProducesTwoConsecutiveWithNote() throws {
        // Find a vriddhi (repeated) tithi in 2024 by scanning sunrise panchanga,
        // then confirm the engine returns both days with the repeatedTithi note.
        var previous: Panchanga?
        var found: (masa: Int, tithi: Int)?
        var day = try XCTUnwrap(GregorianDay(year: 2024, month: 1, day: 1))
        let end = try XCTUnwrap(GregorianDay(year: 2024, month: 12, day: 31))
        while day <= end {
            let p = try engine.panchanga(for: day, location: ujjain)
            if let prev = previous, prev.tithi == p.tithi, prev.masa == p.masa {
                found = (p.masa, p.tithi)
                break
            }
            previous = p
            day = day.adding(days: 1)
        }
        let target = try XCTUnwrap(found, "no repeated tithi found in 2024")
        let spec = CalendarDateSpec(
            system: .indianPanchanga, variant: .indianPanchangaDefault,
            year: nil, month: target.masa, day: target.tithi,
            dayBoundary: .sunrise, calculationLocation: ujjain
        )
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2024)
        let repeated = occ.filter { $0.notes.contains(.repeatedTithi) }
        XCTAssertGreaterThanOrEqual(repeated.count, 2)
    }

    func testDefaultLocationAddsNote() throws {
        let spec = CalendarDateSpec(system: .indianPanchanga, variant: .indianPanchangaDefault, year: nil, month: 1, day: 9)
        let occ = try engine.occurrences(of: spec, inGregorianYear: 2024)
        XCTAssertEqual(occ.first?.day, GregorianDay(year: 2024, month: 4, day: 17))
        XCTAssertTrue(occ.first?.notes.contains(.locationDefaulted) ?? false)
    }

    func testIncompleteLocationThrowsInsteadOfUsingZeroCoordinates() throws {
        let incomplete = CalculationLocation(identifier: "partial", timeZoneIdentifier: "Asia/Kolkata")
        let spec = CalendarDateSpec(
            system: .indianPanchanga,
            variant: .indianPanchangaDefault,
            year: nil,
            month: 1,
            day: 9,
            dayBoundary: .sunrise,
            calculationLocation: incomplete
        )

        XCTAssertThrowsError(try engine.panchanga(for: XCTUnwrap(GregorianDay(year: 2024, month: 4, day: 17)), location: incomplete)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .requiresLocation(system: .indianPanchanga))
        }
        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .requiresLocation(system: .indianPanchanga))
        }
    }

    func testRejectsUnsupportedVariant() {
        let spec = CalendarDateSpec(system: .indianPanchanga, variant: .standard, year: nil, month: 1, day: 9)

        XCTAssertThrowsError(try engine.occurrences(of: spec, inGregorianYear: 2024)) { error in
            XCTAssertEqual(error as? CalendarEngineError, .unsupportedVariant(.standard))
        }
    }

    func testDateSpecRoundTrip() throws {
        // Sample days across the year (sunrise computation is expensive).
        let samples = [(1, 20), (4, 17), (5, 23), (7, 21), (9, 7), (11, 1)]
        for (m, d) in samples {
            let day = try XCTUnwrap(GregorianDay(year: 2024, month: m, day: d))
            let spec = try engine.dateSpec(from: day)
            let back = try engine.occurrences(of: spec, inGregorianYear: day.year).map(\.day)
            XCTAssertTrue(back.contains(day), "round-trip failed for \(day): \(back)")
        }
    }

    func testCapability() {
        let cap = engine.capability
        XCTAssertTrue(cap.requiresLocation)
        XCTAssertTrue(cap.isHeavy)
        XCTAssertEqual(cap.defaultProvider, .astronomy)
    }
}
