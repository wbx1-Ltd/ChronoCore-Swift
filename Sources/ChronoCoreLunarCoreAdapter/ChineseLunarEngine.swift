import ChronoCore
import LunarCore

/// Chinese lunar engine. Wraps LunarCore (the authoritative Chinese lunar
/// implementation) and maps its types to ChronoCore. ChronoCore does not
/// reimplement Chinese rules; it inherits LunarCore's standard and range.
public struct ChineseLunarEngine: CalendarEngine {
    public let system: CalendarSystem = .chineseLunar
    private let calendar: LunarCalendar

    public init(calendar: LunarCalendar = .shared) {
        self.calendar = calendar
    }

    /// Actual Gregorian window: from Chinese New Year of the first supported lunar
    /// year to the last day of the last supported lunar year (which spills into the
    /// following Gregorian year).
    private var supportedGregorianRange: ClosedRange<GregorianDay> {
        let range = calendar.supportedYearRange
        let lower: GregorianDay = calendar.lunarNewYear(in: range.lowerBound)
            .flatMap { GregorianDay(year: $0.year, month: $0.month, day: $0.day) }
            ?? GregorianDay(year: range.lowerBound, month: 2, day: 1)!
        let lastMonthDays = calendar.daysInMonth(12, isLeap: false, year: range.upperBound) ?? 30
        let upper: GregorianDay = LunarDate(year: range.upperBound, month: 12, day: lastMonthDays)
            .flatMap { calendar.solarDate(from: $0) }
            .flatMap { GregorianDay(year: $0.year, month: $0.month, day: $0.day) }
            ?? GregorianDay(year: range.upperBound + 1, month: 1, day: 31)!
        return lower...upper
    }

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .chineseLunar,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: supportedGregorianRange,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .dependency,
            providerDataVersion: "lunarcore-\(LunarCalendar.version)",
            supportedVariants: [.chineseMainland]
        )
    }

    public func occurrences(
        of spec: CalendarDateSpec,
        inGregorianYear year: Int
    ) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .chineseMainland else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard (1...12).contains(spec.month), (1...30).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }
        // Query year must fall within the actual Gregorian window (the upper bound
        // year is the Gregorian year the last lunar year ends in).
        let gregorianRange = supportedGregorianRange
        guard year >= gregorianRange.lowerBound.year, year <= gregorianRange.upperBound.year else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }

        // Yearful spec: a single fixed lunar date. Emit it only in its Gregorian year.
        if let lunarYear = spec.year {
            guard calendar.supportedYearRange.contains(lunarYear) else {
                throw CalendarEngineError.outOfSupportedRange(system: system, year: lunarYear)
            }
            guard let resolved = resolve(lunarYear: lunarYear, spec: spec) else { return [] }
            guard resolved.solar.year == year else { return [] }
            return [occurrence(from: resolved, spec: spec)]
        }

        // Yearless spec: a recurring lunar anniversary. The lunar date can land in
        // this Gregorian year from the lunar year that began in `year - 1` or `year`.
        var results: [CalendarOccurrence] = []
        let supportedLunarYears = calendar.supportedYearRange
        for lunarYear in (year - 1)...year where supportedLunarYears.contains(lunarYear) {
            guard let resolved = resolve(lunarYear: lunarYear, spec: spec) else { continue }
            if resolved.solar.year == year {
                results.append(occurrence(from: resolved, spec: spec))
            }
        }
        return results
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        guard let solar = SolarDate(year: gregorianDay.year, month: gregorianDay.month, day: gregorianDay.day),
              let lunar = calendar.lunarDate(from: solar)
        else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        return CalendarDateSpec(
            system: .chineseLunar,
            variant: .chineseMainland,
            year: lunar.year,
            month: lunar.month,
            day: lunar.day,
            isLeapMonth: lunar.isLeapMonth,
            dayBoundary: .civilMidnight(timeZoneIdentifier: "Asia/Shanghai")
        )
    }

    // MARK: - Resolution

    private struct Resolved {
        var solar: SolarDate
        var notes: [OccurrenceNote]
    }

    private func resolve(lunarYear: Int, spec: CalendarDateSpec) -> Resolved? {
        var notes: [OccurrenceNote] = []
        let wantLeap = spec.isLeapMonth == true
        var useLeap = false

        if wantLeap {
            if calendar.leapMonth(in: lunarYear) == spec.month {
                useLeap = true
            } else {
                // Requested leap month does not exist this lunar year.
                if spec.recurrencePolicy == .leapMonthOnly {
                    return nil
                }
                notes.append(.leapMonthFallbackToRegular)
            }
        } else if spec.recurrencePolicy == .leapMonthOnly {
            return nil
        }

        guard let monthDays = calendar.daysInMonth(spec.month, isLeap: useLeap, year: lunarYear) else {
            return nil
        }
        var day = spec.day
        if day > monthDays {
            guard spec.recurrencePolicy == .engineDefault || spec.recurrencePolicy == .nearestValidDay else {
                return nil
            }
            day = monthDays
            notes.append(.monthLengthClamped)
        }
        guard let lunar = LunarDate(year: lunarYear, month: spec.month, day: day, isLeapMonth: useLeap),
              let solar = calendar.solarDate(from: lunar)
        else {
            return nil
        }
        return Resolved(solar: solar, notes: notes)
    }

    private func occurrence(from resolved: Resolved, spec: CalendarDateSpec) -> CalendarOccurrence {
        CalendarOccurrence(
            day: GregorianDay(year: resolved.solar.year, month: resolved.solar.month, day: resolved.solar.day)!,
            sourceSpec: spec,
            provider: .dependency,
            confidence: .canonical,
            notes: resolved.notes
        )
    }
}
