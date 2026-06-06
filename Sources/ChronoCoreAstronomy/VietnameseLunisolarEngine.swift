import ChronoCore

/// Vietnamese lunisolar engine (am lich), modern UTC+7 standard (Ho Ngoc Duc).
/// New moons and the winter-solstice month 11 are computed at Vietnam civil time,
/// which produces documented differences from the Chinese calendar (for example
/// Tet 1985). Validated against Foundation .vietnamese where available.
public struct VietnameseLunisolarEngine: CalendarEngine {
    public let system: CalendarSystem = .vietnameseLunisolar
    /// Modern Vietnamese standard adopted UTC+7 from 1968; earlier dates belong to
    /// the reserved historical (UTC+8) variant and are out of scope for v1.
    private let core = LunisolarEngineCore(
        system: .vietnameseLunisolar,
        variant: .vietnameseModernUTC7,
        lunisolar: Lunisolar(timeZoneHours: 7.0),
        supportedRange: GregorianDay(year: 1968, month: 1, day: 1)!
            ... GregorianDay(year: 2099, month: 12, day: 31)!
    )

    public init() {}

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .vietnameseLunisolar,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: core.supportedRange,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .astronomy,
            providerDataVersion: "astronomy-vsop87d-elp2000-utc7-1",
            supportedVariants: [.vietnameseModernUTC7],
            isHeavy: true
        )
    }

    public func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        try core.occurrences(of: spec, inGregorianYear: year)
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        try core.dateSpec(from: gregorianDay)
    }
}
