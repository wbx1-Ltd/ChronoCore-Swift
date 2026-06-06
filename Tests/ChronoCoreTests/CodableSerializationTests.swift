import ChronoCore
import ChronoCoreAstronomy
import ChronoCoreFoundation
import ChronoCoreTesting
import Foundation
import XCTest

final class CodableSerializationTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(value, decoded, file: file, line: line)
    }

    func testValueTypes() throws {
        try roundTrip(XCTUnwrap(GregorianDay(year: 2024, month: 2, day: 29)))
        try roundTrip(CalculationLocation(identifier: "x", latitude: 1.5, longitude: -2.5, timeZoneIdentifier: "UTC"))
        try roundTrip(CalculationLocation())
    }

    func testEnums() throws {
        for v in CalendarSystem.allCases {
            try roundTrip(v)
        }
        for v in CalendarVariant.allCases {
            try roundTrip(v)
        }
        for v in RecurrencePolicy.allCases {
            try roundTrip(v)
        }
        for v in EngineProviderKind.allCases {
            try roundTrip(v)
        }
        for v in ValidationConfidence.allCases {
            try roundTrip(v)
        }
        for v in OccurrenceNote.allCases {
            try roundTrip(v)
        }
        for v in HebrewMonth.allCases {
            try roundTrip(v)
        }
    }

    func testSpecAndOccurrence() throws {
        let spec = CalendarDateSpec(
            system: .chineseLunar, variant: .chineseMainland, era: "e",
            year: 2024, month: 8, day: 15, isLeapMonth: false,
            dayBoundary: .civilMidnight(timeZoneIdentifier: "Asia/Shanghai"),
            recurrencePolicy: .exactMonthDay,
            calculationLocation: CalculationLocation(identifier: "sh")
        )
        try roundTrip(spec)
        let occ = try CalendarOccurrence(
            day: XCTUnwrap(GregorianDay(year: 2024, month: 9, day: 17)),
            sourceSpec: spec, provider: .dependency, confidence: .canonical,
            notes: [.leapMonthFallbackToRegular, .monthLengthClamped]
        )
        try roundTrip(occ)
    }

    func testCapabilityAndFingerprint() throws {
        try roundTrip(GregorianEngine().capability)
        let fp = CalendarComputationFingerprint(
            engineVersion: "1.0",
            spec: CalendarDateSpec(system: .hebrew, variant: .hebrewCivil, year: 5785, month: 1, day: 1),
            providerDataVersion: "p"
        )
        try roundTrip(fp)
    }

    func testPanchanga() throws {
        try roundTrip(Panchanga(tithi: 15, paksha: .shukla, nakshatra: 16, yoga: 19, karana: 29, masa: 2, isAdhikaMasa: false))
    }

    func testGoldenFixtureDecodesEverySchema() throws {
        // Every fixture file in the bundle must decode under the schema.
        let names = [
            "gregorian-basic", "chinese-lunar", "hebrew", "hijri-umm-al-qura",
            "korean-lunisolar", "vietnamese-lunisolar", "indian-panchanga",
            "nepali-bikram-sambat", "bangla"
        ]
        for name in names {
            let fixtures = try FixtureHarness.fixtures(name)
            XCTAssertFalse(fixtures.isEmpty, "\(name) empty")
            // Re-encode and decode to confirm the schema is symmetric.
            for fixture in fixtures {
                let data = try JSONEncoder().encode(fixture)
                _ = try JSONDecoder().decode(GoldenFixture.self, from: data)
            }
        }
    }
}
