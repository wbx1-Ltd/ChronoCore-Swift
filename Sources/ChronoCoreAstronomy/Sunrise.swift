import ChronoCore
import Foundation

/// Sunrise instant for a civil day at a location. Returns the Julian Day (UT) of
/// the upward crossing of the standard sunrise altitude (-0.833 degrees, allowing
/// for refraction and the solar semidiameter). Returns nil when the Sun does not
/// rise that day (polar cases).
enum Sunrise {
    private static let standardAltitude = -0.833

    static func julianDay(
        civilDay: GregorianDay,
        latitude: Double,
        longitude: Double,
        timeZoneHours: Double
    ) throws -> Double? {
        let localMidnightUT = Double(civilDay.julianDayNumber) - 0.5 - timeZoneHours / 24.0
        let start = localMidnightUT + 2.0 / 24.0 // 02:00 local
        let end = localMidnightUT + 11.0 / 24.0 // 11:00 local
        let stepMinutes = 10.0
        let step = stepMinutes / (24.0 * 60.0)

        var previousJD = start
        var previousF = try altitudeOffset(previousJD, latitude, longitude)
        var t = start + step
        while t <= end {
            let f = try altitudeOffset(t, latitude, longitude)
            if previousF < 0 && f >= 0 {
                return try bisect(previousJD, t, latitude, longitude)
            }
            previousJD = t
            previousF = f
            t += step
        }
        return nil
    }

    private static func altitudeOffset(_ jd: Double, _ lat: Double, _ lon: Double) throws -> Double {
        try Astronomy.solarAltitude(julianDay: jd, latitude: lat, longitude: lon) - standardAltitude
    }

    private static func bisect(_ lo: Double, _ hi: Double, _ lat: Double, _ lon: Double) throws -> Double {
        var low = lo
        var high = hi
        for _ in 0..<40 {
            let mid = (low + high) / 2
            if abs(high - low) < 1e-6 { return mid }
            let f = try altitudeOffset(mid, lat, lon)
            if f < 0 { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }
}
