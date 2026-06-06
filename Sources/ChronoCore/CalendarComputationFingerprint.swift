/// Stable cache key for a calendar computation. Every component that can change
/// a result is folded in: engine version, system, variant, source date, era,
/// leap marker, recurrence policy, day boundary, location, provider data version.
public struct CalendarComputationFingerprint: Codable, Hashable, Sendable {
    public var engineVersion: String
    public var system: CalendarSystem
    public var variant: CalendarVariant
    public var specHash: String
    public var boundaryHash: String
    public var locationHash: String?
    public var providerDataVersion: String

    public init(
        engineVersion: String,
        system: CalendarSystem,
        variant: CalendarVariant,
        specHash: String,
        boundaryHash: String,
        locationHash: String?,
        providerDataVersion: String
    ) {
        self.engineVersion = engineVersion
        self.system = system
        self.variant = variant
        self.specHash = specHash
        self.boundaryHash = boundaryHash
        self.locationHash = locationHash
        self.providerDataVersion = providerDataVersion
    }

    public init(
        engineVersion: String,
        spec: CalendarDateSpec,
        providerDataVersion: String
    ) {
        self.engineVersion = engineVersion
        self.system = spec.system
        self.variant = spec.variant
        self.specHash = DeterministicHash.fnv1aHex(Self.canonicalSpec(spec))
        self.boundaryHash = DeterministicHash.fnv1aHex(Self.canonicalBoundary(spec.dayBoundary))
        self.locationHash = spec.calculationLocation.map {
            DeterministicHash.fnv1aHex(Self.canonicalLocation($0))
        }
        self.providerDataVersion = providerDataVersion
    }

    /// Stable string key for this fingerprint, suitable as a cache key.
    public var cacheKey: String {
        [
            engineVersion,
            system.rawValue,
            variant.rawValue,
            specHash,
            boundaryHash,
            locationHash ?? "-",
            providerDataVersion
        ].joined(separator: ":")
    }

    private static func canonicalSpec(_ spec: CalendarDateSpec) -> String {
        [
            spec.system.rawValue,
            spec.variant.rawValue,
            spec.era ?? "-",
            spec.year.map(String.init) ?? "nil",
            String(spec.month),
            String(spec.day),
            spec.isLeapMonth.map { $0 ? "L" : "N" } ?? "-",
            spec.recurrencePolicy.rawValue
        ].joined(separator: "|")
    }

    private static func canonicalBoundary(_ boundary: DayBoundary) -> String {
        switch boundary {
        case .engineDefault:
            "engineDefault"
        case .civilMidnight(let tz):
            "civilMidnight|\(tz)"
        case .sunset(let bornAfterSunset):
            "sunset|\(bornAfterSunset.map { $0 ? "1" : "0" } ?? "nil")"
        case .sunrise:
            "sunrise"
        }
    }

    private static func canonicalLocation(_ location: CalculationLocation) -> String {
        [
            location.identifier ?? "-",
            location.latitude.map(canonicalCoordinate) ?? "-",
            location.longitude.map(canonicalCoordinate) ?? "-",
            location.timeZoneIdentifier ?? "-"
        ].joined(separator: "|")
    }

    /// Coordinate rounded to a stable 1e-6 grid without Foundation formatting.
    private static func canonicalCoordinate(_ value: Double) -> String {
        let scaled = (value * 1000000).rounded()
        return String(Int64(scaled))
    }
}
