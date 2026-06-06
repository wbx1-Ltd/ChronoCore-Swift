import ChronoCore
import Foundation

/// The five limbs of the Panchanga at a single instant, plus the lunar month.
public struct Panchanga: Sendable, Hashable, Codable {
    public enum Paksha: String, Sendable, Hashable, Codable {
        case shukla // waxing, tithi 1...15
        case krishna // waning, tithi 16...30
    }

    public var tithi: Int // 1...30
    public var paksha: Paksha
    public var nakshatra: Int // 1...27
    public var yoga: Int // 1...27
    public var karana: Int // 1...60 (half-tithi index)
    public var masa: Int // 1...12 (Chaitra = 1)
    public var isAdhikaMasa: Bool

    public init(tithi: Int, paksha: Paksha, nakshatra: Int, yoga: Int, karana: Int, masa: Int, isAdhikaMasa: Bool) {
        self.tithi = tithi
        self.paksha = paksha
        self.nakshatra = nakshatra
        self.yoga = yoga
        self.karana = karana
        self.masa = masa
        self.isAdhikaMasa = isAdhikaMasa
    }
}

/// Computes Panchanga limbs from AstroCore positions with Lahiri ayanamsa.
/// Sidereal quantities (nakshatra, yoga, masa) use the ayanamsa; tithi and karana
/// use the Sun-Moon elongation where the ayanamsa cancels.
final class PanchangaCalculator: @unchecked Sendable {
    private static let synodic = 29.530588853
    private static let epoch = 2415021.076998695

    private enum PanchangaCacheEntry {
        case noSunrise
        case value(Panchanga)
    }

    private struct PanchangaCacheKey: Hashable {
        var julianDayNumber: Int
        var latitude: Double
        var longitude: Double
        var timeZoneHours: Double
    }

    private let lock = NSLock()
    private var newMoonCache: [Int: Double] = [:]
    private var sunriseCache: [PanchangaCacheKey: Double?] = [:]
    private var panchangaCache: [PanchangaCacheKey: PanchangaCacheEntry] = [:]

    private func newMoonJD(_ k: Int) throws -> Double {
        lock.lock()
        if let v = newMoonCache[k] { lock.unlock()
            return v
        }
        lock.unlock()
        let v = try Astronomy.newMoonJulianDay(k)
        lock.lock()
        newMoonCache[k] = v
        lock.unlock()
        return v
    }

    private func newMoonIndex(forJD jd: Double) throws -> Int {
        var k = Int(((jd - Self.epoch) / Self.synodic).rounded(.down))
        while try newMoonJD(k + 1) <= jd {
            k += 1
        }
        while try newMoonJD(k) > jd {
            k -= 1
        }
        return k
    }

    private func normalize(_ value: Double) -> Double {
        var v = value.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    /// Limbs that do not need the lunar month.
    func limbs(atJD jd: Double) throws -> (tithi: Int, nakshatra: Int, yoga: Int, karana: Int) {
        let (sun, moon) = try Astronomy.sunAndMoonLongitude(julianDay: jd)
        let ayan = Ayanamsa.lahiri(julianDay: jd)
        let elongation = normalize(moon - sun)
        let tithi = Int(elongation / 12.0) + 1
        let karana = Int(elongation / 6.0) + 1
        let moonSidereal = normalize(moon - ayan)
        let nakshatra = Int(moonSidereal / (360.0 / 27.0)) + 1
        let sumSidereal = normalize(sun + moon - 2 * ayan)
        let yoga = Int(sumSidereal / (360.0 / 27.0)) + 1
        return (tithi, nakshatra, yoga, karana)
    }

    /// Amanta lunar month (masa) and adhika flag for the lunar month containing jd.
    func masa(atJD jd: Double) throws -> (masa: Int, isAdhika: Bool) {
        let k = try newMoonIndex(forJD: jd)
        let start = try newMoonJD(k)
        let end = try newMoonJD(k + 1)
        let signStart = try Astronomy.siderealSunSign(julianDay: start + 0.01)
        let signEnd = try Astronomy.siderealSunSign(julianDay: end - 0.01)
        let masa = ((signStart + 1) % 12) + 1
        // No solar sign change within the lunar month means an intercalary month.
        let isAdhika = signStart == signEnd
        return (masa, isAdhika)
    }

    func sunrise(civilDay: GregorianDay, location: CalculationLocation, timeZoneHours: Double) throws -> Double? {
        guard let latitude = location.latitude, let longitude = location.longitude else {
            throw CalendarEngineError.requiresLocation(system: .indianPanchanga)
        }
        let key = PanchangaCacheKey(
            julianDayNumber: civilDay.julianDayNumber,
            latitude: latitude,
            longitude: longitude,
            timeZoneHours: timeZoneHours
        )
        lock.lock()
        if let cached = sunriseCache[key] { lock.unlock()
            return cached
        }
        lock.unlock()
        let value = try Sunrise.julianDay(
            civilDay: civilDay,
            latitude: latitude,
            longitude: longitude,
            timeZoneHours: timeZoneHours
        )
        lock.lock()
        sunriseCache[key] = value
        lock.unlock()
        return value
    }

    /// Full Panchanga prevailing at sunrise of a civil day. Returns nil if the Sun
    /// does not rise (polar day handling).
    func panchanga(civilDay: GregorianDay, location: CalculationLocation, timeZoneHours: Double) throws -> Panchanga? {
        guard let latitude = location.latitude, let longitude = location.longitude else {
            throw CalendarEngineError.requiresLocation(system: .indianPanchanga)
        }
        let key = PanchangaCacheKey(
            julianDayNumber: civilDay.julianDayNumber,
            latitude: latitude,
            longitude: longitude,
            timeZoneHours: timeZoneHours
        )
        lock.lock()
        if let cached = panchangaCache[key] {
            lock.unlock()
            switch cached {
            case .noSunrise: return nil
            case .value(let panchanga): return panchanga
            }
        }
        lock.unlock()

        guard let sr = try sunrise(civilDay: civilDay, location: location, timeZoneHours: timeZoneHours) else {
            lock.lock()
            panchangaCache[key] = .noSunrise
            lock.unlock()
            return nil
        }
        let l = try limbs(atJD: sr)
        let m = try masa(atJD: sr)
        let result = Panchanga(
            tithi: l.tithi,
            paksha: l.tithi <= 15 ? .shukla : .krishna,
            nakshatra: l.nakshatra,
            yoga: l.yoga,
            karana: l.karana,
            masa: m.masa,
            isAdhikaMasa: m.isAdhika
        )
        lock.lock()
        panchangaCache[key] = .value(result)
        lock.unlock()
        return result
    }
}
