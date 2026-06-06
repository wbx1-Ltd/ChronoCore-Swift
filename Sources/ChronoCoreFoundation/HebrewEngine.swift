import ChronoCore
import Foundation

/// Hebrew engine backed by Foundation .hebrew (ICU arithmetic Hebrew). Exposes a
/// stable HebrewMonth identity and documents Adar recurrence across common and
/// leap years. Day boundary is sunset based; precise per-location sunset is
/// future work, so the flag is recorded in notes rather than computed.
public struct HebrewEngine: CalendarEngine {
    public let system: CalendarSystem = .hebrew

    private let hebrew: Calendar
    private let gregorian: Calendar

    public init() {
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = TimeZone(identifier: "UTC")!
        self.hebrew = hebrew
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        self.gregorian = gregorian
    }

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .hebrew,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: GregorianDay(year: 1900, month: 1, day: 1)!
                ... GregorianDay(year: 2200, month: 12, day: 31)!,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .foundation,
            providerDataVersion: "foundation-hebrew-icu",
            supportedVariants: [.hebrewCivil]
        )
    }

    public func occurrences(
        of spec: CalendarDateSpec,
        inGregorianYear year: Int
    ) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .hebrewCivil else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard capability.supportedGregorianRange?.contains(GregorianDay(year: year, month: 1, day: 1)!) == true else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
        guard let month = HebrewMonth(stableCode: spec.month) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }
        guard (1...30).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }

        // Hebrew year is about Gregorian + 3760/3761; dates of a Hebrew year fall
        // across two Gregorian years, so check a small candidate window.
        let candidateYears: [Int] = if let hebrewYear = spec.year {
            [hebrewYear]
        } else {
            [year + 3759, year + 3760, year + 3761]
        }

        var results: [CalendarOccurrence] = []
        for hebrewYear in candidateYears {
            guard let resolved = resolve(month: month, day: spec.day, hebrewYear: hebrewYear, spec: spec) else {
                continue
            }
            if resolved.day.year == year {
                results.append(resolved)
            }
        }
        return results.sorted { $0.day < $1.day }
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        guard capability.supportedGregorianRange?.contains(gregorianDay) == true else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        guard let date = gregorian.date(from: DateComponents(year: gregorianDay.year, month: gregorianDay.month, day: gregorianDay.day, hour: 12)) else {
            throw CalendarEngineError.invalidDate(system: system, month: gregorianDay.month, day: gregorianDay.day)
        }
        let comps = hebrew.dateComponents([.year, .month, .day], from: date)
        guard let hy = comps.year, let icuMonth = comps.month, let day = comps.day,
              let month = HebrewMonth.from(icuMonth: icuMonth, hebrewYear: hy)
        else {
            throw CalendarEngineError.providerUnavailable(system: system, detail: "Foundation .hebrew returned no components")
        }
        return CalendarDateSpec(
            system: .hebrew,
            variant: .hebrewCivil,
            year: hy,
            month: month.stableCode,
            day: day,
            dayBoundary: .sunset(bornAfterSunset: nil)
        )
    }

    // MARK: - Resolution

    private func resolve(
        month: HebrewMonth,
        day: Int,
        hebrewYear: Int,
        spec: CalendarDateSpec
    ) -> CalendarOccurrence? {
        var notes: [OccurrenceNote] = []
        let mapped = month.icuMonth(hebrewYear: hebrewYear)
        if let note = mapped.note { notes.append(note) }

        var comps = DateComponents()
        comps.era = 0
        comps.year = hebrewYear
        comps.month = mapped.month
        comps.day = day
        guard let date = hebrew.date(from: comps) else { return nil }

        // ICU rolls invalid days into the next month; confirm the date is exact.
        let back = hebrew.dateComponents([.year, .month, .day], from: date)
        if back.month != mapped.month || back.day != day {
            if spec.recurrencePolicy == .nearestValidDay {
                // Clamp to the last valid day of the requested month.
                guard let lastDay = lastDay(ofICUMonth: mapped.month, hebrewYear: hebrewYear),
                      let clamped = gregorianDay(hebrewYear: hebrewYear, icuMonth: mapped.month, day: lastDay)
                else { return nil }
                notes.append(.monthLengthClamped)
                return occurrence(day: clamped, spec: spec, boundaryNotes(spec) + notes)
            }
            return nil
        }

        let gregComps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let g = gregorianDayFrom(gregComps) else { return nil }
        return occurrence(day: g, spec: spec, boundaryNotes(spec) + notes)
    }

    private func boundaryNotes(_ spec: CalendarDateSpec) -> [OccurrenceNote] {
        if case .sunset(let bornAfterSunset) = spec.dayBoundary {
            if bornAfterSunset == nil { return [.bornAfterSunsetUnspecified] }
            if bornAfterSunset == true { return [.dayAdvancedForSunset] }
        }
        return []
    }

    private func lastDay(ofICUMonth icuMonth: Int, hebrewYear: Int) -> Int? {
        var comps = DateComponents()
        comps.era = 0
        comps.year = hebrewYear
        comps.month = icuMonth
        comps.day = 1
        guard let date = hebrew.date(from: comps) else { return nil }
        return hebrew.range(of: .day, in: .month, for: date)?.count
    }

    private func gregorianDay(hebrewYear: Int, icuMonth: Int, day: Int) -> GregorianDay? {
        var comps = DateComponents()
        comps.era = 0
        comps.year = hebrewYear
        comps.month = icuMonth
        comps.day = day
        guard let date = hebrew.date(from: comps) else { return nil }
        return gregorianDayFrom(gregorian.dateComponents([.year, .month, .day], from: date))
    }

    private func gregorianDayFrom(_ comps: DateComponents) -> GregorianDay? {
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        return GregorianDay(year: y, month: m, day: d)
    }

    private func occurrence(day: GregorianDay, spec: CalendarDateSpec, _ notes: [OccurrenceNote]) -> CalendarOccurrence {
        CalendarOccurrence(
            day: day,
            sourceSpec: spec,
            provider: .foundation,
            confidence: .canonical,
            notes: notes
        )
    }
}

extension HebrewEngine {
    /// Convenience to build a spec from a typed Hebrew month.
    public static func spec(
        year: Int?,
        month: HebrewMonth,
        day: Int,
        bornAfterSunset: Bool? = nil,
        recurrencePolicy: RecurrencePolicy = .engineDefault
    ) -> CalendarDateSpec {
        CalendarDateSpec(
            system: .hebrew,
            variant: .hebrewCivil,
            year: year,
            month: month.stableCode,
            day: day,
            dayBoundary: .sunset(bornAfterSunset: bornAfterSunset),
            recurrencePolicy: recurrencePolicy
        )
    }
}
