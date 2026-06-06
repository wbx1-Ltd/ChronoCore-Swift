/// Proleptic Gregorian date arithmetic via Julian Day Numbers.
/// Used by table-driven engines (anchor plus offset), reverse conversions, and
/// range iteration. Correct for the package target ranges (well within the
/// proleptic Gregorian domain where the integer formulas use positive operands).
extension GregorianDay {
    /// Julian Day Number at this civil date (noon-based integer JDN).
    public var julianDayNumber: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    /// Builds a civil date from a Julian Day Number. Always valid.
    public init(julianDayNumber jdn: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146097
        let c = a - (146097 * b) / 4
        let d = (4 * c + 3) / 1461
        let e = c - (1461 * d) / 4
        let m = (5 * e + 2) / 153
        let day = e - (153 * m + 2) / 5 + 1
        let month = m + 3 - 12 * (m / 10)
        let year = 100 * b + d - 4800 + m / 10
        // Components are guaranteed consistent; use the validating initializer
        // and fall back is impossible for in-domain inputs.
        self = GregorianDay(year: year, month: month, day: day)!
    }

    /// Returns the civil date that is `days` after this one.
    public func adding(days: Int) -> GregorianDay {
        GregorianDay(julianDayNumber: julianDayNumber + days)
    }

    /// Number of whole days from `other` to this date (this minus other).
    public func days(since other: GregorianDay) -> Int {
        julianDayNumber - other.julianDayNumber
    }
}
