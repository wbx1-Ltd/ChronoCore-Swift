import ChronoCore
import Foundation

/// East Asian lunisolar conversion (Ho Ngoc Duc method) parameterised by the
/// civil meridian time zone. New moons and the winter-solstice month 11 are
/// computed from AstroCore high-precision positions, then assigned to a civil day
/// at the given offset. Korea uses UTC+9, Vietnam UTC+7, China UTC+8.
/// Thread-safe memo of expensive conjunction and solar-sector lookups, shared by
/// one engine instance across queries.
final class LunisolarCache: @unchecked Sendable {
    private let lock = NSLock()
    private var newMoon: [Int: Int] = [:]
    private var sunSector: [Int: Int] = [:]

    /// compute() runs outside the lock on purpose: the conjunction search is
    /// multi-second, so holding the lock would serialise all callers. A concurrent
    /// duplicate compute for the same key is harmless because the value is
    /// deterministic and the last write wins.
    func newMoon(_ k: Int, _ compute: () throws -> Int) rethrows -> Int {
        lock.lock()
        if let cached = newMoon[k] { lock.unlock()
            return cached
        }
        lock.unlock()
        let value = try compute()
        lock.lock()
        newMoon[k] = value
        lock.unlock()
        return value
    }

    func sunSector(_ dayNumber: Int, _ compute: () throws -> Int) rethrows -> Int {
        lock.lock()
        if let cached = sunSector[dayNumber] { lock.unlock()
            return cached
        }
        lock.unlock()
        let value = try compute()
        lock.lock()
        sunSector[dayNumber] = value
        lock.unlock()
        return value
    }
}

struct Lunisolar {
    // IANA-free fixed offset in hours from UTC for civil-day assignment.
    let timeZoneHours: Double
    private let cache = LunisolarCache()

    private static let synodicMonth = 29.530588853
    private static let newMoonEpoch = 2415021.076998695

    struct LunarDate: Equatable {
        var year: Int
        var month: Int
        var day: Int
        var isLeapMonth: Bool
    }

    /// JDN of the civil day (in this time zone) of the k-th new moon since epoch.
    func newMoonDay(_ k: Int) throws -> Int {
        try cache.newMoon(k) {
            let meanJD = Self.newMoonEpoch + Double(k) * Self.synodicMonth
            let conjunction = try Astronomy.conjunctionJulianDay(nearMean: meanJD)
            return Int((conjunction + 0.5 + timeZoneHours / 24.0).rounded(.down))
        }
    }

    /// Sun longitude sector 0...11 (each 30 degrees) at local midnight starting
    /// civil day `dayNumber`. A new sector means a major solar term was crossed.
    func sunLongitudeSector(_ dayNumber: Int) throws -> Int {
        try cache.sunSector(dayNumber) {
            let jd = Double(dayNumber) - 0.5 - timeZoneHours / 24.0
            let longitude = try Astronomy.sunLongitude(julianDay: jd)
            return Int((longitude / 30.0).rounded(.down)) % 12
        }
    }

    /// JDN of the start of lunar month 11 (the month containing the winter
    /// solstice) for a Gregorian year.
    func lunarMonth11(gregorianYear: Int) throws -> Int {
        let off = GregorianDay(year: gregorianYear, month: 12, day: 31)!.julianDayNumber - 2415021
        let k = Int((Double(off) / Self.synodicMonth).rounded(.down))
        var nm = try newMoonDay(k)
        if try sunLongitudeSector(nm) >= 9 {
            nm = try newMoonDay(k - 1)
        }
        return nm
    }

    /// Offset (in months from month 11) of the leap month in a 13-month year.
    func leapMonthOffset(_ a11: Int) throws -> Int {
        let k = Int(((Double(a11) - Self.newMoonEpoch) / Self.synodicMonth + 0.5).rounded(.down))
        var i = 1
        var arc = try sunLongitudeSector(newMoonDay(k + i))
        var last: Int
        repeat {
            last = arc
            i += 1
            arc = try sunLongitudeSector(newMoonDay(k + i))
        } while arc != last && i < 14
        return i - 1
    }

    func solarToLunar(_ day: GregorianDay) throws -> LunarDate {
        let dayNumber = day.julianDayNumber
        var k = Int(((Double(dayNumber) - Self.newMoonEpoch) / Self.synodicMonth).rounded(.down))
        // Find the index whose new moon is the latest on or before this day. The
        // mean estimate can be off by one when a precise new moon lands near
        // local midnight, so converge instead of assuming a single step.
        while try newMoonDay(k + 1) <= dayNumber {
            k += 1
        }
        while try newMoonDay(k) > dayNumber {
            k -= 1
        }
        let monthStart = try newMoonDay(k)
        var a11 = try lunarMonth11(gregorianYear: day.year)
        var b11 = a11
        var lunarYear: Int
        if a11 >= monthStart {
            lunarYear = day.year
            a11 = try lunarMonth11(gregorianYear: day.year - 1)
        } else {
            lunarYear = day.year + 1
            b11 = try lunarMonth11(gregorianYear: day.year + 1)
        }
        let lunarDay = dayNumber - monthStart + 1
        let diff = Int((Double(monthStart - a11) / 29.0).rounded(.down))
        var lunarLeap = false
        var lunarMonth = diff + 11
        if b11 - a11 > 365 {
            let leapMonthDiff = try leapMonthOffset(a11)
            if diff >= leapMonthDiff {
                lunarMonth = diff + 10
                if diff == leapMonthDiff { lunarLeap = true }
            }
        }
        if lunarMonth > 12 { lunarMonth -= 12 }
        if lunarMonth >= 11 && diff < 4 { lunarYear -= 1 }
        return LunarDate(year: lunarYear, month: lunarMonth, day: lunarDay, isLeapMonth: lunarLeap)
    }

    /// New moon index (k + off) for a lunar month, or nil if the requested leap
    /// month does not exist that lunar year.
    func monthIndex(year: Int, month: Int, isLeapMonth: Bool) throws -> Int? {
        var a11: Int
        var b11: Int
        if month < 11 {
            a11 = try lunarMonth11(gregorianYear: year - 1)
            b11 = try lunarMonth11(gregorianYear: year)
        } else {
            a11 = try lunarMonth11(gregorianYear: year)
            b11 = try lunarMonth11(gregorianYear: year + 1)
        }
        var off = month - 11
        if off < 0 { off += 12 }
        if b11 - a11 > 365 {
            let leapOff = try leapMonthOffset(a11)
            var leapMonth = leapOff - 2
            if leapMonth < 0 { leapMonth += 12 }
            if isLeapMonth && month != leapMonth {
                return nil
            } else if isLeapMonth || off >= leapOff {
                off += 1
            }
        } else if isLeapMonth {
            return nil
        }
        let k = Int((0.5 + (Double(a11) - Self.newMoonEpoch) / Self.synodicMonth).rounded(.down))
        return k + off
    }

    /// Civil day length (29 or 30) of a lunar month given its new moon index.
    func monthLength(index: Int) throws -> Int {
        try newMoonDay(index + 1) - newMoonDay(index)
    }

    // Convenience: lunar date to Gregorian day (no clamping), or nil if invalid.
    func lunarToSolar(year: Int, month: Int, day: Int, isLeapMonth: Bool) throws -> GregorianDay? {
        guard let index = try monthIndex(year: year, month: month, isLeapMonth: isLeapMonth) else {
            return nil
        }
        let monthStart = try newMoonDay(index)
        return GregorianDay(julianDayNumber: monthStart + day - 1)
    }
}
