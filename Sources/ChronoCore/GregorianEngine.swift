/// Proleptic Gregorian engine. Pure, deterministic, date-only.
public struct GregorianEngine: CalendarEngine {
    public let system: CalendarSystem = .gregorian
    private static let supportedRange = GregorianDay(year: 1600, month: 1, day: 1)!
        ... GregorianDay(year: 2400, month: 12, day: 31)!

    public init() {}

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .gregorian,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: Self.supportedRange,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .algorithmic,
            providerDataVersion: "gregorian-proleptic-1",
            supportedVariants: [.standard]
        )
    }

    public func occurrences(
        of spec: CalendarDateSpec,
        inGregorianYear year: Int
    ) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .standard else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard Self.supportedRange.lowerBound.year...Self.supportedRange.upperBound.year ~= year else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
        if let fixedYear = spec.year {
            guard Self.supportedRange.lowerBound.year...Self.supportedRange.upperBound.year ~= fixedYear else {
                throw CalendarEngineError.outOfSupportedRange(system: system, year: fixedYear)
            }
            guard fixedYear == year else { return [] }
        }

        if let day = GregorianDay(year: year, month: spec.month, day: spec.day) {
            return [
                CalendarOccurrence(day: day, sourceSpec: spec, provider: .algorithmic)
            ]
        }

        // Only February 29 can be a valid month/day that is absent in a given year.
        guard spec.month == 2, spec.day == 29 else {
            throw CalendarEngineError.invalidDate(
                system: spec.system,
                month: spec.month,
                day: spec.day
            )
        }

        switch spec.recurrencePolicy {
        case .nearestValidDay:
            // Non-leap year: collapse February 29 to February 28.
            guard let fallback = GregorianDay(year: year, month: 2, day: 28) else {
                return []
            }
            return [
                CalendarOccurrence(
                    day: fallback,
                    sourceSpec: spec,
                    provider: .algorithmic,
                    notes: [.adjustedToNearestValidDay]
                )
            ]
        default:
            // engineDefault and others skip the leap day in non-leap years.
            return []
        }
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        guard Self.supportedRange.contains(gregorianDay) else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        return CalendarDateSpec(
            system: .gregorian,
            variant: .standard,
            year: gregorianDay.year,
            month: gregorianDay.month,
            day: gregorianDay.day
        )
    }
}
