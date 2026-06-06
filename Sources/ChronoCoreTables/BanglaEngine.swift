import ChronoCore

/// Bangla engine, Bangladesh revised variant (Bangla Academy 2019 reform).
/// Rule driven: Pohela Boishakh is fixed to Gregorian April 14, the first six
/// months have 31 days, the next six have 30, and Falgun (month 11) absorbs the
/// leap day (29 days normally, 30 when the spanning Gregorian year is leap). This
/// keeps the reform national-day alignments (21 Feb = 8 Falgun, 16 Dec = 1 Poush,
/// 15 Aug = 31 Srabon, 26 Mar = 12 Choitro). Foundation .bangla is the traditional
/// (West Bengal style) calendar and is not used here.
///
/// The rule is applied across a 200 year window. Before the 2019 reform the
/// official Bangladesh calendar used drifting rules; pre-reform results are the
/// revised rule projected backward and carry a historicalRuleVersion note. The
/// bangladeshHistorical and westBengalTraditional variants are reserved.
public struct BanglaEngine: CalendarEngine {
    public let system: CalendarSystem = .bangla

    // Bangla year B starts on April 14 of Gregorian year B + 593.
    private static let gregorianYearOffset = 593
    private static let reformBanglaYear = 1426 // 2019
    private let supportedBanglaYears = 1326...1526 // about 1919...2119 Gregorian

    public init() {}

    public var capability: CalendarSystemCapability {
        let lower = boishakhFirst(banglaYear: supportedBanglaYears.lowerBound)
        let upper = boishakhFirst(banglaYear: supportedBanglaYears.upperBound + 1).adding(days: -1)
        return CalendarSystemCapability(
            system: .bangla,
            isImplemented: true,
            isValidated: true,
            supportedGregorianRange: lower...upper,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .table,
            providerDataVersion: "bangla-bangladesh-revised-2019",
            supportedVariants: [.bangladeshRevised]
        )
    }

    public func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .bangladeshRevised else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard (1...12).contains(spec.month), (1...31).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }

        let candidateYears: [Int] = if let banglaYear = spec.year {
            [banglaYear]
        } else {
            [year - Self.gregorianYearOffset - 1, year - Self.gregorianYearOffset]
        }

        var results: [CalendarOccurrence] = []
        for banglaYear in candidateYears {
            guard supportedBanglaYears.contains(banglaYear) else { continue }
            guard let resolved = resolve(banglaYear: banglaYear, month: spec.month, day: spec.day, spec: spec) else { continue }
            if resolved.day.year == year {
                results.append(resolved)
            }
        }
        return results.sorted { $0.day < $1.day }
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        // The Bangla year whose Boishakh 1 is on or before this day.
        var banglaYear = gregorianDay.year - Self.gregorianYearOffset
        if gregorianDay < boishakhFirst(banglaYear: banglaYear) {
            banglaYear -= 1
        }
        guard supportedBanglaYears.contains(banglaYear) else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        var offset = gregorianDay.days(since: boishakhFirst(banglaYear: banglaYear))
        for month in 1...12 {
            let length = monthLength(banglaYear: banglaYear, month: month)
            if offset < length {
                var notes: [OccurrenceNote] = []
                if banglaYear < Self.reformBanglaYear { notes.append(.historicalRuleVersion) }
                return CalendarDateSpec(
                    system: .bangla,
                    variant: .bangladeshRevised,
                    year: banglaYear,
                    month: month,
                    day: offset + 1,
                    dayBoundary: .civilMidnight(timeZoneIdentifier: "Asia/Dhaka")
                )
            }
            offset -= length
        }
        throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
    }

    // MARK: - Rule

    private func boishakhFirst(banglaYear: Int) -> GregorianDay {
        GregorianDay(year: banglaYear + Self.gregorianYearOffset, month: 4, day: 14)!
    }

    private func isLeap(banglaYear: Int) -> Bool {
        // The leap day falls in Falgun when the Gregorian year containing the
        // tail of the Bangla year (B + 594) is a leap year.
        GregorianDay.isLeapYear(banglaYear + Self.gregorianYearOffset + 1)
    }

    private func monthLength(banglaYear: Int, month: Int) -> Int {
        switch month {
        case 1...6: 31
        case 11: isLeap(banglaYear: banglaYear) ? 30 : 29
        default: 30
        }
    }

    private func resolve(banglaYear: Int, month: Int, day: Int, spec: CalendarDateSpec) -> CalendarOccurrence? {
        let length = monthLength(banglaYear: banglaYear, month: month)
        var notes: [OccurrenceNote] = []
        var effectiveDay = day
        if day > length {
            guard spec.recurrencePolicy == .engineDefault || spec.recurrencePolicy == .nearestValidDay else {
                return nil
            }
            effectiveDay = length
            notes.append(.monthLengthClamped)
        }
        if banglaYear < Self.reformBanglaYear { notes.append(.historicalRuleVersion) }

        var offset = 0
        for m in 1..<month {
            offset += monthLength(banglaYear: banglaYear, month: m)
        }
        offset += effectiveDay - 1
        let day = boishakhFirst(banglaYear: banglaYear).adding(days: offset)
        return CalendarOccurrence(day: day, sourceSpec: spec, provider: .table, confidence: .canonical, notes: notes)
    }
}
