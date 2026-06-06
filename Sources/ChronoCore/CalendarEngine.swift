public protocol CalendarEngine: Sendable {
    var system: CalendarSystem { get }
    var capability: CalendarSystemCapability { get }

    /// Occurrences of a spec within a single Gregorian calendar year.
    /// Returns 0, 1, or many occurrences.
    func occurrences(
        of spec: CalendarDateSpec,
        inGregorianYear year: Int
    ) throws -> [CalendarOccurrence]

    /// Occurrences of a spec within an inclusive Gregorian day range.
    func occurrences(
        of spec: CalendarDateSpec,
        in range: ClosedRange<GregorianDay>
    ) throws -> [CalendarOccurrence]

    /// The calendar date spec that a Gregorian day maps to in this system.
    func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec
}

extension CalendarEngine {
    /// Stable cache fingerprint for a computation with this engine and spec.
    public func fingerprint(for spec: CalendarDateSpec) -> CalendarComputationFingerprint {
        CalendarComputationFingerprint(
            engineVersion: ChronoCoreInfo.version,
            spec: spec,
            providerDataVersion: capability.providerDataVersion
        )
    }

    /// Default range iteration delegates to the per-year API, deduplicating and
    /// clamping to the requested range. Engines may override for efficiency.
    public func occurrences(
        of spec: CalendarDateSpec,
        in range: ClosedRange<GregorianDay>
    ) throws -> [CalendarOccurrence] {
        guard range.lowerBound <= range.upperBound else {
            throw CalendarEngineError.invalidRange
        }
        var results: [CalendarOccurrence] = []
        var seen: Set<GregorianDay> = []
        for year in range.lowerBound.year...range.upperBound.year {
            for occurrence in try occurrences(of: spec, inGregorianYear: year)
                where range.contains(occurrence.day) && seen.insert(occurrence.day).inserted
            {
                results.append(occurrence)
            }
        }
        return results.sorted { $0.day < $1.day }
    }
}

public enum CalendarEngineError: Error, Equatable, Sendable {
    case unsupportedSystem(CalendarSystem)
    case unsupportedVariant(CalendarVariant)
    case invalidDate(system: CalendarSystem, month: Int, day: Int)
    case invalidRange
    case outOfSupportedRange(system: CalendarSystem, year: Int)
    case requiresLocation(system: CalendarSystem)
    case providerUnavailable(system: CalendarSystem, detail: String)
}
