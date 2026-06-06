import ChronoCore

/// Shared recurrence and conversion logic for meridian-parameterised lunisolar
/// engines (Korean UTC+9, Vietnamese UTC+7). Each engine differs only by time
/// zone, system, variant, and provider metadata.
struct LunisolarEngineCore {
    let system: CalendarSystem
    let variant: CalendarVariant
    let lunisolar: Lunisolar
    /// Supported Gregorian window, kept inside the AstroCore range with a margin
    /// because conversions read the neighbouring years.
    let supportedRange: ClosedRange<GregorianDay>

    func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == variant else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard (1...12).contains(spec.month), (1...30).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }
        guard year >= supportedRange.lowerBound.year, year <= supportedRange.upperBound.year else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }

        do {
            if let lunarYear = spec.year {
                guard let resolved = try resolve(lunarYear: lunarYear, spec: spec) else { return [] }
                return resolved.day.year == year ? [resolved] : []
            }
            var results: [CalendarOccurrence] = []
            for lunarYear in (year - 1)...year {
                guard let resolved = try resolve(lunarYear: lunarYear, spec: spec) else { continue }
                if resolved.day.year == year { results.append(resolved) }
            }
            return results.sorted { $0.day < $1.day }
        } catch is Astronomy.OutOfRange {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
    }

    func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        do {
            let lunar = try lunisolar.solarToLunar(gregorianDay)
            return CalendarDateSpec(
                system: system,
                variant: variant,
                year: lunar.year,
                month: lunar.month,
                day: lunar.day,
                isLeapMonth: lunar.isLeapMonth,
                dayBoundary: .civilMidnight(timeZoneIdentifier: timeZoneIdentifier)
            )
        } catch is Astronomy.OutOfRange {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
    }

    var timeZoneIdentifier: String {
        switch system {
        case .koreanLunisolar: "Asia/Seoul"
        case .vietnameseLunisolar: "Asia/Ho_Chi_Minh"
        default: "UTC"
        }
    }

    // MARK: - Resolution

    private func resolve(lunarYear: Int, spec: CalendarDateSpec) throws -> CalendarOccurrence? {
        let wantLeap = spec.isLeapMonth == true
        var notes: [OccurrenceNote] = []
        var useLeap = wantLeap

        var index = try lunisolar.monthIndex(year: lunarYear, month: spec.month, isLeapMonth: useLeap)
        if index == nil {
            if wantLeap {
                if spec.recurrencePolicy == .leapMonthOnly { return nil }
                // Requested leap month absent this year: fall back to the regular month.
                useLeap = false
                notes.append(.leapMonthFallbackToRegular)
                index = try lunisolar.monthIndex(year: lunarYear, month: spec.month, isLeapMonth: false)
            }
        } else if !wantLeap && spec.recurrencePolicy == .leapMonthOnly {
            return nil
        }
        guard let monthIndex = index else { return nil }

        let monthStart = try lunisolar.newMoonDay(monthIndex)
        let length = try lunisolar.monthLength(index: monthIndex)
        var day = spec.day
        if day > length {
            guard spec.recurrencePolicy == .engineDefault || spec.recurrencePolicy == .nearestValidDay else {
                return nil
            }
            day = length
            notes.append(.monthLengthClamped)
        }
        let result = GregorianDay(julianDayNumber: monthStart + day - 1)
        return CalendarOccurrence(
            day: result,
            sourceSpec: spec,
            provider: .astronomy,
            confidence: .canonical,
            notes: notes
        )
    }
}
