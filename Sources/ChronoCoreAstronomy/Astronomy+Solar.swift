import AstroCore
import Foundation

/// Solar geometry helpers for sunrise and sidereal sign work.
extension Astronomy {
    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    /// Mean obliquity of the ecliptic in degrees (Laskar). Nutation in obliquity
    /// is under 0.003 degrees and is omitted; ample for sunrise to the minute.
    static func meanObliquity(julianDay jd: Double) -> Double {
        let t = (jd - 2451545.0) / 36525.0
        return 23.4392911 - 0.0130041667 * t - 1.638e-7 * t * t + 5.036e-7 * t * t * t
    }

    /// Apparent solar altitude in degrees at a location and instant.
    static func solarAltitude(julianDay jd: Double, latitude: Double, longitude: Double) throws -> Double {
        let m = try moment(julianDay: jd)
        let lambda = radians(AstroCalculator.sunPosition(for: m).longitude)
        let eps = radians(meanObliquity(julianDay: jd))
        let ra = atan2(sin(lambda) * cos(eps), cos(lambda))
        let dec = asin(sin(eps) * sin(lambda))
        let last = radians(AstroCalculator.localSiderealTimeDegrees(for: m, longitude: longitude))
        let hourAngle = last - ra
        let phi = radians(latitude)
        let sinAlt = sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(hourAngle)
        return degrees(asin(min(1, max(-1, sinAlt))))
    }

    /// Sidereal solar sign index 0...11 (Mesha = 0) at an instant using Lahiri.
    static func siderealSunSign(julianDay jd: Double) throws -> Int {
        let tropical = try sunLongitude(julianDay: jd)
        var sidereal = (tropical - Ayanamsa.lahiri(julianDay: jd)).truncatingRemainder(dividingBy: 360)
        if sidereal < 0 { sidereal += 360 }
        return Int(sidereal / 30.0) % 12
    }

    /// Conjunction (new moon) Julian Day for the k-th new moon since epoch.
    static func newMoonJulianDay(_ k: Int) throws -> Double {
        let meanJD = 2415021.076998695 + Double(k) * 29.530588853
        return try conjunctionJulianDay(nearMean: meanJD)
    }
}
