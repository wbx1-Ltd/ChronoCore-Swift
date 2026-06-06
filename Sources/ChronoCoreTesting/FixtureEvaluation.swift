import ChronoCore
import Foundation

/// Pure evaluation of a golden fixture against an engine. The test target turns
/// the result into assertions; this target stays free of XCTest.
public struct FixtureOccurrence: Equatable, Sendable {
    public var day: GregorianDay
    public var provider: EngineProviderKind
    public var confidence: ValidationConfidence
    public var notes: [OccurrenceNote]

    public init(_ occurrence: CalendarOccurrence) {
        day = occurrence.day
        provider = occurrence.provider
        confidence = occurrence.confidence
        notes = occurrence.notes
    }
}

public struct FixtureEvaluation: Equatable, Sendable {
    public var id: String
    public var expected: [GregorianDay]
    public var actualOccurrences: [FixtureOccurrence]
    public var expectedProvider: EngineProviderKind?
    public var expectedConfidence: ValidationConfidence?
    public var expectedNotes: [OccurrenceNote]?

    public var actual: [GregorianDay] { actualOccurrences.map(\.day) }
    public var missing: [GregorianDay] { Self.unmatched(expected, against: actual) }
    public var unexpected: [GregorianDay] { Self.unmatched(actual, against: expected) }

    public var providerMismatches: [FixtureOccurrence] {
        guard let expectedProvider else { return [] }
        return actualOccurrences.filter { $0.provider != expectedProvider }
    }

    public var confidenceMismatches: [FixtureOccurrence] {
        guard let expectedConfidence else { return [] }
        return actualOccurrences.filter { $0.confidence != expectedConfidence }
    }

    public var notesMismatches: [FixtureOccurrence] {
        guard let expectedNotes else { return [] }
        return actualOccurrences.filter { $0.notes != expectedNotes }
    }

    public var matches: Bool {
        expected == actual
            && providerMismatches.isEmpty
            && confidenceMismatches.isEmpty
            && notesMismatches.isEmpty
    }

    public var failureMessage: String {
        if matches { return "" }
        var message = "Fixture \(id) mismatch. expected=\(expected.map(\.description)) "
            + "actual=\(actual.map(\.description)) "
            + "missing=\(missing.map(\.description)) unexpected=\(unexpected.map(\.description))"
        if !providerMismatches.isEmpty {
            message += " providerMismatches=\(providerMismatches)"
        }
        if !confidenceMismatches.isEmpty {
            message += " confidenceMismatches=\(confidenceMismatches)"
        }
        if !notesMismatches.isEmpty {
            message += " notesMismatches=\(notesMismatches)"
        }
        return message
    }

    private static func unmatched(_ values: [GregorianDay], against other: [GregorianDay]) -> [GregorianDay] {
        var remaining = other
        var result: [GregorianDay] = []
        for value in values {
            if let index = remaining.firstIndex(of: value) {
                remaining.remove(at: index)
            } else {
                result.append(value)
            }
        }
        return result
    }
}

public enum FixtureRunner {
    /// Evaluates a fixture, enumerating occurrences over its declared query
    /// window (or the years of its expected days when no query is given).
    public static func evaluate(
        _ fixture: GoldenFixture,
        with engine: any CalendarEngine
    ) throws -> FixtureEvaluation {
        let spec = fixture.spec()
        let expected = fixture.expectedGregorianDays.sorted()
        let occurrences: [CalendarOccurrence]

        switch fixture.query {
        case .gregorianYear(let year):
            occurrences = try engine.occurrences(of: spec, inGregorianYear: year)
        case .range(let from, let to):
            occurrences = try engine.occurrences(of: spec, in: from...to)
        case nil:
            let years = Set(expected.map(\.year))
            guard !years.isEmpty else {
                throw FixtureError.noQueryWindow(fixture.id)
            }
            var collected: [CalendarOccurrence] = []
            for year in years.sorted() {
                try collected.append(contentsOf: engine.occurrences(of: spec, inGregorianYear: year))
            }
            occurrences = collected
        }

        let actualOccurrences = occurrences
            .sorted { lhs, rhs in
                if lhs.day != rhs.day { return lhs.day < rhs.day }
                if lhs.provider != rhs.provider { return lhs.provider.rawValue < rhs.provider.rawValue }
                if lhs.confidence != rhs.confidence { return lhs.confidence.rawValue < rhs.confidence.rawValue }
                return lhs.notes.map(\.rawValue).joined(separator: ",") < rhs.notes.map(\.rawValue).joined(separator: ",")
            }
            .map(FixtureOccurrence.init)
        return FixtureEvaluation(
            id: fixture.id,
            expected: expected,
            actualOccurrences: actualOccurrences,
            expectedProvider: fixture.expectedProvider,
            expectedConfidence: fixture.confidence,
            expectedNotes: fixture.expectedNotes
        )
    }

    public enum FixtureError: Error, Equatable, Sendable {
        case noQueryWindow(String)
    }
}
