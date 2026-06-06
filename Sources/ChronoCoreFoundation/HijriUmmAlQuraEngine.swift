import ChronoCore
import Foundation

/// Hijri Umm al-Qura engine backed by Foundation .islamicUmmAlQura (ICU embeds
/// the official KACST Umm al-Qura table). This is the Saudi civil calendar, not a
/// generic tabular Hijri and not all Islamic calendars. Months 1...12, days
/// 1...30. Because a Hijri year is about 11 days shorter than a Gregorian year, a
/// Hijri date can occur zero, one, or two times within a single Gregorian year.
public struct HijriUmmAlQuraEngine: CalendarEngine {
    public let system: CalendarSystem = .hijriUmmAlQura

    private let hijri: Calendar
    private let gregorian: Calendar

    public init() {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = TimeZone(identifier: "UTC")!
        self.hijri = hijri
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        self.gregorian = gregorian
    }

    public var capability: CalendarSystemCapability {
        // ICU Umm al-Qura table spans about AH 1300...1600 (AD 1882...2174).
        CalendarSystemCapability(
            system: .hijriUmmAlQura,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: GregorianDay(year: 1900, month: 1, day: 1)!
                ... GregorianDay(year: 2100, month: 12, day: 31)!,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .foundation,
            providerDataVersion: "foundation-islamic-umalqura-icu",
            supportedVariants: [.ummAlQuraSaudi]
        )
    }

    public func occurrences(
        of spec: CalendarDateSpec,
        inGregorianYear year: Int
    ) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .ummAlQuraSaudi else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard capability.supportedGregorianRange?.contains(GregorianDay(year: year, month: 1, day: 1)!) == true else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
        guard (1...12).contains(spec.month), (1...30).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }

        let candidateYears: [Int]
        if let hijriYear = spec.year {
            candidateYears = [hijriYear]
        } else {
            guard
                let start = gregorian.date(from: DateComponents(year: year, month: 1, day: 1, hour: 12)),
                let end = gregorian.date(from: DateComponents(year: year, month: 12, day: 31, hour: 12))
            else {
                throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
            }
            let ahStart = hijri.component(.year, from: start)
            let ahEnd = hijri.component(.year, from: end)
            candidateYears = Array(ahStart...ahEnd)
        }

        var results: [CalendarOccurrence] = []
        for hijriYear in candidateYears {
            guard let occurrence = resolve(hijriYear: hijriYear, spec: spec) else { continue }
            if occurrence.day.year == year {
                results.append(occurrence)
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
        let comps = hijri.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            throw CalendarEngineError.providerUnavailable(system: system, detail: "Foundation .islamicUmmAlQura returned no components")
        }
        return CalendarDateSpec(
            system: .hijriUmmAlQura,
            variant: .ummAlQuraSaudi,
            year: y,
            month: m,
            day: d
        )
    }

    private func resolve(hijriYear: Int, spec: CalendarDateSpec) -> CalendarOccurrence? {
        var comps = DateComponents()
        comps.era = 0
        comps.year = hijriYear
        comps.month = spec.month
        comps.day = spec.day
        guard let date = hijri.date(from: comps) else { return nil }

        let back = hijri.dateComponents([.year, .month, .day], from: date)
        if back.month != spec.month || back.day != spec.day {
            // Day does not exist this Hijri year (for example day 30 of a 29-day month).
            if spec.recurrencePolicy == .nearestValidDay {
                guard let length = monthLength(hijriYear: hijriYear, month: spec.month),
                      let clamped = gregorianDay(hijriYear: hijriYear, month: spec.month, day: length)
                else { return nil }
                return occurrence(day: clamped, spec: spec, notes: [.monthLengthClamped])
            }
            return nil
        }

        guard let g = gregorianDayFrom(gregorian.dateComponents([.year, .month, .day], from: date)) else {
            return nil
        }
        return occurrence(day: g, spec: spec, notes: [])
    }

    private func monthLength(hijriYear: Int, month: Int) -> Int? {
        var comps = DateComponents()
        comps.era = 0
        comps.year = hijriYear
        comps.month = month
        comps.day = 1
        guard let date = hijri.date(from: comps) else { return nil }
        return hijri.range(of: .day, in: .month, for: date)?.count
    }

    private func gregorianDay(hijriYear: Int, month: Int, day: Int) -> GregorianDay? {
        var comps = DateComponents()
        comps.era = 0
        comps.year = hijriYear
        comps.month = month
        comps.day = day
        guard let date = hijri.date(from: comps) else { return nil }
        return gregorianDayFrom(gregorian.dateComponents([.year, .month, .day], from: date))
    }

    private func gregorianDayFrom(_ comps: DateComponents) -> GregorianDay? {
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        return GregorianDay(year: y, month: m, day: d)
    }

    private func occurrence(day: GregorianDay, spec: CalendarDateSpec, notes: [OccurrenceNote]) -> CalendarOccurrence {
        CalendarOccurrence(day: day, sourceSpec: spec, provider: .foundation, confidence: .canonical, notes: notes)
    }
}
