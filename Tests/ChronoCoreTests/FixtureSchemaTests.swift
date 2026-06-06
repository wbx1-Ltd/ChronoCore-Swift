@testable import ChronoCore
@testable import ChronoCoreTesting
import XCTest

final class FixtureSchemaTests: XCTestCase {
    func testDecodesGoldenFixture() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "gregorian-basic",
                withExtension: "json"
            )
        )

        let fixtures = try GoldenFixture.loadArray(from: url)

        XCTAssertEqual(fixtures.count, 1)
        XCTAssertEqual(fixtures[0].id, "gregorian-yearless-2026-001")
        XCTAssertEqual(fixtures[0].system, .gregorian)
        XCTAssertEqual(fixtures[0].variant, .standard)
        XCTAssertEqual(fixtures[0].expectedGregorianDays, [
            GregorianDay(year: 2026, month: 3, day: 14)
        ])
    }

    func testFixtureEvaluationDetectsDuplicateActualOccurrences() throws {
        let day = try XCTUnwrap(GregorianDay(year: 2026, month: 3, day: 14))
        let fixture = GoldenFixture(
            id: "duplicate-actual",
            system: .gregorian,
            variant: .standard,
            source: .init(year: nil, month: 3, day: 14),
            query: .gregorianYear(2026),
            expectedGregorianDays: [day]
        )

        let evaluation = try FixtureRunner.evaluate(fixture, with: DuplicateGregorianEngine(day: day))

        XCTAssertFalse(evaluation.matches)
        XCTAssertEqual(evaluation.actual, [day, day])
    }

    func testFixtureEvaluationChecksProviderConfidenceAndNotes() throws {
        let day = try XCTUnwrap(GregorianDay(year: 2026, month: 3, day: 14))
        let fixture = GoldenFixture(
            id: "provenance",
            system: .gregorian,
            variant: .standard,
            source: .init(year: nil, month: 3, day: 14),
            query: .gregorianYear(2026),
            expectedGregorianDays: [day],
            expectedProvider: .foundation,
            confidence: .providerVerified,
            expectedNotes: [.providerVerified]
        )

        let evaluation = try FixtureRunner.evaluate(fixture, with: ProvenanceMismatchEngine(day: day))

        XCTAssertFalse(evaluation.matches)
    }

    func testRangeCheckRejectsNonPositiveStep() throws {
        let day = try XCTUnwrap(GregorianDay(year: 2026, month: 3, day: 14))
        let report = RangeCheck.roundTrip(engine: GregorianEngine(), from: day, to: day, step: 0)

        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.checked, 0)
    }
}

private struct DuplicateGregorianEngine: CalendarEngine {
    let day: GregorianDay
    let system: CalendarSystem = .gregorian
    var capability: CalendarSystemCapability { GregorianEngine().capability }

    func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        [
            CalendarOccurrence(day: day, sourceSpec: spec, provider: .algorithmic),
            CalendarOccurrence(day: day, sourceSpec: spec, provider: .algorithmic)
        ]
    }

    func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        try GregorianEngine().dateSpec(from: gregorianDay)
    }
}

private struct ProvenanceMismatchEngine: CalendarEngine {
    let day: GregorianDay
    let system: CalendarSystem = .gregorian
    var capability: CalendarSystemCapability { GregorianEngine().capability }

    func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        [
            CalendarOccurrence(day: day, sourceSpec: spec, provider: .algorithmic, confidence: .canonical)
        ]
    }

    func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        try GregorianEngine().dateSpec(from: gregorianDay)
    }
}
