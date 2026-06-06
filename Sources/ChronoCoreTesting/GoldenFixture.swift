import ChronoCore
import Foundation

/// Golden fixture schema. Drives conversion, recurrence, range, and provider
/// parity tests from source-backed JSON. Supports 0, 1, or many expected days.
public struct GoldenFixture: Codable, Equatable, Sendable {
    public var id: String
    public var system: CalendarSystem
    public var variant: CalendarVariant
    public var source: GoldenFixtureSource
    public var recurrencePolicy: RecurrencePolicy?
    public var dayBoundary: DayBoundary
    public var location: CalculationLocation?
    public var query: GoldenFixtureQuery?
    public var expectedGregorianDays: [GregorianDay]
    public var expectedProvider: EngineProviderKind?
    public var confidence: ValidationConfidence?
    public var expectedNotes: [OccurrenceNote]?
    public var official: OfficialSourceMetadata?
    public var parity: ProviderParityMetadata?
    public var sourceReferences: [String]
    public var notes: [String]

    public init(
        id: String,
        system: CalendarSystem,
        variant: CalendarVariant,
        source: GoldenFixtureSource,
        recurrencePolicy: RecurrencePolicy? = nil,
        dayBoundary: DayBoundary = .engineDefault,
        location: CalculationLocation? = nil,
        query: GoldenFixtureQuery? = nil,
        expectedGregorianDays: [GregorianDay],
        expectedProvider: EngineProviderKind? = nil,
        confidence: ValidationConfidence? = nil,
        expectedNotes: [OccurrenceNote]? = nil,
        official: OfficialSourceMetadata? = nil,
        parity: ProviderParityMetadata? = nil,
        sourceReferences: [String] = [],
        notes: [String] = []
    ) {
        self.id = id
        self.system = system
        self.variant = variant
        self.source = source
        self.recurrencePolicy = recurrencePolicy
        self.dayBoundary = dayBoundary
        self.location = location
        self.query = query
        self.expectedGregorianDays = expectedGregorianDays
        self.expectedProvider = expectedProvider
        self.confidence = confidence
        self.expectedNotes = expectedNotes
        self.official = official
        self.parity = parity
        self.sourceReferences = sourceReferences
        self.notes = notes
    }

    /// The calendar date spec encoded by this fixture's source block.
    public func spec() -> CalendarDateSpec {
        CalendarDateSpec(
            system: system,
            variant: variant,
            era: source.era,
            year: source.year,
            month: source.month,
            day: source.day,
            isLeapMonth: source.isLeapMonth,
            dayBoundary: dayBoundary,
            recurrencePolicy: recurrencePolicy ?? .engineDefault,
            calculationLocation: location
        )
    }

    public static func loadArray(from url: URL) throws -> [GoldenFixture] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([GoldenFixture].self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case id, system, variant, source, recurrencePolicy, dayBoundary, location
        case query, expectedGregorianDays, expectedProvider, confidence
        case expectedNotes, official, parity, sourceReferences, notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        system = try c.decode(CalendarSystem.self, forKey: .system)
        variant = try c.decode(CalendarVariant.self, forKey: .variant)
        source = try c.decode(GoldenFixtureSource.self, forKey: .source)
        recurrencePolicy = try c.decodeIfPresent(RecurrencePolicy.self, forKey: .recurrencePolicy)
        dayBoundary = try c.decodeIfPresent(DayBoundary.self, forKey: .dayBoundary) ?? .engineDefault
        location = try c.decodeIfPresent(CalculationLocation.self, forKey: .location)
        query = try c.decodeIfPresent(GoldenFixtureQuery.self, forKey: .query)
        expectedGregorianDays = try c.decode([GregorianDay].self, forKey: .expectedGregorianDays)
        expectedProvider = try c.decodeIfPresent(EngineProviderKind.self, forKey: .expectedProvider)
        confidence = try c.decodeIfPresent(ValidationConfidence.self, forKey: .confidence)
        expectedNotes = try c.decodeIfPresent([OccurrenceNote].self, forKey: .expectedNotes)
        official = try c.decodeIfPresent(OfficialSourceMetadata.self, forKey: .official)
        parity = try c.decodeIfPresent(ProviderParityMetadata.self, forKey: .parity)
        sourceReferences = try c.decodeIfPresent([String].self, forKey: .sourceReferences) ?? []
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
    }
}

public struct GoldenFixtureSource: Codable, Equatable, Sendable {
    public var era: String?
    public var year: Int?
    public var month: Int
    public var day: Int
    public var isLeapMonth: Bool?

    public init(era: String? = nil, year: Int?, month: Int, day: Int, isLeapMonth: Bool? = nil) {
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

/// How a fixture enumerates Gregorian occurrences for comparison.
public enum GoldenFixtureQuery: Codable, Equatable, Sendable {
    case gregorianYear(Int)
    case range(from: GregorianDay, to: GregorianDay)

    private enum CodingKeys: String, CodingKey {
        case gregorianYear, from, to
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let year = try c.decodeIfPresent(Int.self, forKey: .gregorianYear) {
            self = .gregorianYear(year)
            return
        }
        let from = try c.decode(GregorianDay.self, forKey: .from)
        let to = try c.decode(GregorianDay.self, forKey: .to)
        self = .range(from: from, to: to)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gregorianYear(let year):
            try c.encode(year, forKey: .gregorianYear)
        case .range(let from, let to):
            try c.encode(from, forKey: .from)
            try c.encode(to, forKey: .to)
        }
    }
}

/// Provenance for the expected values: which standard or authority backs them.
public struct OfficialSourceMetadata: Codable, Equatable, Sendable {
    public var standard: String?
    public var authority: String?
    public var reference: String?
    public var note: String?

    public init(standard: String? = nil, authority: String? = nil, reference: String? = nil, note: String? = nil) {
        self.standard = standard
        self.authority = authority
        self.reference = reference
        self.note = note
    }
}

/// Environment captured when a Foundation-backed parity fixture was generated.
public struct ProviderParityMetadata: Codable, Equatable, Sendable {
    public var provider: EngineProviderKind?
    public var os: String?
    public var sdk: String?
    public var locale: String?
    public var timeZone: String?
    public var calendarIdentifier: String?

    public init(
        provider: EngineProviderKind? = nil,
        os: String? = nil,
        sdk: String? = nil,
        locale: String? = nil,
        timeZone: String? = nil,
        calendarIdentifier: String? = nil
    ) {
        self.provider = provider
        self.os = os
        self.sdk = sdk
        self.locale = locale
        self.timeZone = timeZone
        self.calendarIdentifier = calendarIdentifier
    }
}
