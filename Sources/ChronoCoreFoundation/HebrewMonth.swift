import ChronoCore

/// Stable Hebrew month identity. ChronoCore does not expose raw ICU month
/// integers as business semantics; this enum is the public, serialization-stable
/// identity, and the engine maps it to ICU month numbers internally.
public enum HebrewMonth: String, CaseIterable, Codable, Hashable, Sendable {
    case tishrei, cheshvan, kislev, tevet, shevat
    case adar // the single Adar of a common year
    case adarI // intercalary first Adar of a leap year
    case adarII // second Adar of a leap year (where Purim falls)
    case nisan, iyar, sivan, tammuz, av, elul

    /// Stable ChronoCore code carried in CalendarDateSpec.month. Common-year
    /// months keep calendar order 1...12 (Adar = 6); the leap Adars get distinct
    /// codes 13 and 14 so every month has a unique, reversible integer.
    public var stableCode: Int {
        switch self {
        case .tishrei: 1
        case .cheshvan: 2
        case .kislev: 3
        case .tevet: 4
        case .shevat: 5
        case .adar: 6
        case .nisan: 7
        case .iyar: 8
        case .sivan: 9
        case .tammuz: 10
        case .av: 11
        case .elul: 12
        case .adarI: 13
        case .adarII: 14
        }
    }

    public init?(stableCode: Int) {
        guard let match = Self.allCases.first(where: { $0.stableCode == stableCode }) else {
            return nil
        }
        self = match
    }

    public static func isLeapYear(_ hebrewYear: Int) -> Bool {
        ((7 * hebrewYear + 1) % 19) < 7
    }

    /// ICU month integer for this month in a Hebrew year, plus any recurrence
    /// note created when the requested month does not exist that year and is
    /// remapped (Adar across common and leap years).
    func icuMonth(hebrewYear: Int) -> (month: Int, note: OccurrenceNote?) {
        let leap = Self.isLeapYear(hebrewYear)
        switch self {
        case .tishrei: return (1, nil)
        case .cheshvan: return (2, nil)
        case .kislev: return (3, nil)
        case .tevet: return (4, nil)
        case .shevat: return (5, nil)
        case .adar: return leap ? (7, .adarMappedToAdarII) : (7, nil)
        case .adarI: return leap ? (6, nil) : (7, .adarMappedToAdar)
        case .adarII: return leap ? (7, nil) : (7, .adarMappedToAdar)
        case .nisan: return (8, nil)
        case .iyar: return (9, nil)
        case .sivan: return (10, nil)
        case .tammuz: return (11, nil)
        case .av: return (12, nil)
        case .elul: return (13, nil)
        }
    }

    /// Maps an ICU month integer back to the stable identity for a Hebrew year.
    static func from(icuMonth: Int, hebrewYear: Int) -> HebrewMonth? {
        let leap = isLeapYear(hebrewYear)
        switch icuMonth {
        case 1: return .tishrei
        case 2: return .cheshvan
        case 3: return .kislev
        case 4: return .tevet
        case 5: return .shevat
        case 6: return leap ? .adarI : nil
        case 7: return leap ? .adarII : .adar
        case 8: return .nisan
        case 9: return .iyar
        case 10: return .sivan
        case 11: return .tammuz
        case 12: return .av
        case 13: return .elul
        default: return nil
        }
    }
}
