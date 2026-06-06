import ChronoCore

/// Korean lunisolar engine (Dangi / eumnyeok). Computes new moons and the
/// winter-solstice month 11 at Korea Standard Time (UTC+9), following modern KASI
/// practice. Validated against Foundation .dangi where available. ChronoCore does
/// not approximate the Korean calendar with the Chinese one; the meridian differs.
public struct KoreanLunisolarEngine: CalendarEngine {
    public let system: CalendarSystem = .koreanLunisolar
    private let core = LunisolarEngineCore(
        system: .koreanLunisolar,
        variant: .koreanModern,
        lunisolar: Lunisolar(timeZoneHours: 9.0),
        supportedRange: GregorianDay(year: 1900, month: 1, day: 1)!
            ... GregorianDay(year: 2099, month: 12, day: 31)!
    )

    public init() {}

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .koreanLunisolar,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: core.supportedRange,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .astronomy,
            providerDataVersion: "astronomy-vsop87d-elp2000-kst9-1",
            supportedVariants: [.koreanModern],
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
