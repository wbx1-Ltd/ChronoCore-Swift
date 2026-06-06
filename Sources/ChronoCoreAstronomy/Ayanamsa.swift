import Foundation

/// Sidereal correction (ayanamsa). Default is Lahiri (Chitrapaksha), the Indian
/// civil standard. Linear model anchored at J2000.0, accurate to arcminutes over
/// the supported range, which is well within a nakshatra width (13.333 degrees).
enum Ayanamsa {
    // Lahiri value at J2000.0 in degrees, and the precession rate per Julian year.
    private static let lahiriAtJ2000 = 23.853
    private static let rateArcsecPerYear = 50.2388

    static func lahiri(julianDay jd: Double) -> Double {
        let years = (jd - 2451545.0) / 365.25
        return lahiriAtJ2000 + years * (rateArcsecPerYear / 3600.0)
    }
}
