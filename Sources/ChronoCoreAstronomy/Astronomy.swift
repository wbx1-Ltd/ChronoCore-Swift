import AstroCore
import ChronoCore
import Foundation

/// Low-level astronomy backed by AstroCore (VSOP87D Sun, ELP2000 Moon, apparent
/// geocentric longitudes). Works in Julian Day (UT) and feeds the lunisolar and
/// Panchanga engines. Bounded by AstroCore CivilMoment year range 1800...2100.
enum Astronomy {
    static let supportedYearRange: ClosedRange<Int> = 1800...2100

    /// Julian Day (UT) for a Foundation Date.
    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    static func date(julianDay jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }

    struct OutOfRange: Error {}

    /// Builds an AstroCore CivilMoment in UTC for a Julian Day.
    static func moment(julianDay jd: Double) throws -> CivilMoment {
        let date = date(julianDay: jd)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard let year = c.year, supportedYearRange.contains(year) else { throw OutOfRange() }
        do {
            return try CivilMoment(
                year: year, month: c.month ?? 1, day: c.day ?? 1,
                hour: c.hour ?? 0, minute: c.minute ?? 0, second: c.second ?? 0,
                timeZoneIdentifier: "UTC"
            )
        } catch {
            throw OutOfRange()
        }
    }

    /// Apparent geocentric tropical solar longitude in degrees [0,360).
    static func sunLongitude(julianDay jd: Double) throws -> Double {
        try AstroCalculator.sunPosition(for: moment(julianDay: jd)).longitude
    }

    /// Apparent geocentric tropical lunar longitude in degrees [0,360).
    static func moonLongitude(julianDay jd: Double) throws -> Double {
        try AstroCalculator.moonPosition(for: moment(julianDay: jd)).longitude
    }

    /// Sun and Moon longitudes from a single moment construction.
    static func sunAndMoonLongitude(julianDay jd: Double) throws -> (sun: Double, moon: Double) {
        let m = try moment(julianDay: jd)
        return (AstroCalculator.sunPosition(for: m).longitude, AstroCalculator.moonPosition(for: m).longitude)
    }

    /// Signed Sun-Moon elongation in (-180, 180], zero at conjunction.
    static func signedElongation(julianDay jd: Double) throws -> Double {
        let (sun, moon) = try sunAndMoonLongitude(julianDay: jd)
        var d = (moon - sun).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }

    /// Refines the conjunction (new moon) Julian Day near a mean estimate by
    /// bisecting the signed elongation. The Moon gains about 12 degrees per day,
    /// so a +/- 1 day bracket straddles the true conjunction.
    static func conjunctionJulianDay(nearMean meanJD: Double) throws -> Double {
        var lo = meanJD - 1.0
        var hi = meanJD + 1.0
        var flo = try signedElongation(julianDay: lo)
        var fhi = try signedElongation(julianDay: hi)
        var widen = 0
        while flo * fhi > 0 && widen < 3 {
            lo -= 1.0
            hi += 1.0
            flo = try signedElongation(julianDay: lo)
            fhi = try signedElongation(julianDay: hi)
            widen += 1
        }
        // Bisection on the crossing from negative to positive elongation.
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let fmid = try signedElongation(julianDay: mid)
            if abs(hi - lo) < 1e-6 { return mid }
            if (flo < 0 && fmid < 0) || (flo > 0 && fmid > 0) {
                lo = mid
                flo = fmid
            } else {
                hi = mid
                fhi = fmid
            }
        }
        return (lo + hi) / 2
    }
}
