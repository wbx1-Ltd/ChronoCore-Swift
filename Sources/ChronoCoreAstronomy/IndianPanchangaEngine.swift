import ChronoCore
import Foundation

/// Indian Panchanga engine. Computes tithi, nakshatra, yoga, karana, and masa
/// from AstroCore positions with Lahiri ayanamsa, at sunrise for a location
/// (Hindu civil days begin at sunrise). This is the traditional Panchanga, not
/// Foundation .indian (Saka solar) or .vikram (Indian Vikram Samvat).
///
/// Recurrence through CalendarEngine uses month = masa (1...12, Chaitra = 1) and
/// day = tithi (1...30); isLeapMonth marks adhika masa. Nakshatra and full
/// Panchanga are available through the dedicated methods below.
public struct IndianPanchangaEngine: CalendarEngine {
    public let system: CalendarSystem = .indianPanchanga

    /// Traditional Hindu prime meridian (Ujjain) used when a spec omits location.
    public static let defaultLocation = CalculationLocation(
        identifier: "ujjain", latitude: 23.1765, longitude: 75.7885, timeZoneIdentifier: "Asia/Kolkata"
    )

    private static let sharedCalculator = PanchangaCalculator()

    private let defaultLocation: CalculationLocation
    private let calculator: PanchangaCalculator
    private let supportedRange = GregorianDay(year: 1900, month: 1, day: 1)!
        ... GregorianDay(year: 2099, month: 12, day: 31)!

    public init(defaultLocation: CalculationLocation = IndianPanchangaEngine.defaultLocation) {
        self.defaultLocation = defaultLocation
        calculator = Self.sharedCalculator
    }

    public var capability: CalendarSystemCapability {
        CalendarSystemCapability(
            system: .indianPanchanga,
            isImplemented: true,
            // Astronomically validated (Sankranti ayanamsa anchors, full-moon
            // tithi, self-consistency); line-by-line cross-check against a
            // published panchang is pending, so this stays false honestly.
            isValidated: false,
            supportedGregorianRange: supportedRange,
            requiresLocation: true,
            supportsYearlessRecurrence: true,
            defaultProvider: .astronomy,
            providerDataVersion: "astronomy-vsop87d-elp2000-lahiri-1",
            supportedVariants: [.indianPanchangaDefault],
            isHeavy: true
        )
    }

    // MARK: - Public Panchanga API

    public func panchanga(for day: GregorianDay, location: CalculationLocation? = nil) throws -> Panchanga {
        guard supportedRange.contains(day) else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: day.year)
        }
        let (loc, _) = try resolvedLocation(location)
        guard let p = try calculator.panchanga(civilDay: day, location: loc, timeZoneHours: tzHours(loc, on: day)) else {
            throw CalendarEngineError.providerUnavailable(system: system, detail: "no sunrise at location")
        }
        return p
    }

    /// Days in a Gregorian year whose sunrise nakshatra matches the target (1...27).
    public func nakshatraOccurrences(
        nakshatra: Int,
        inGregorianYear year: Int,
        location: CalculationLocation? = nil
    ) throws -> [CalendarOccurrence] {
        guard (1...27).contains(nakshatra) else {
            throw CalendarEngineError.invalidDate(system: system, month: 0, day: nakshatra)
        }
        guard year >= supportedRange.lowerBound.year, year <= supportedRange.upperBound.year else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
        let (loc, defaulted) = try resolvedLocation(location)
        let spec = CalendarDateSpec(
            system: .indianPanchanga, variant: .indianPanchangaDefault,
            year: nil, month: 0, day: nakshatra, dayBoundary: .sunrise, calculationLocation: loc
        )
        return try scan(year: year, location: loc, defaulted: defaulted) { $0.nakshatra == nakshatra }
            .map { CalendarOccurrence(day: $0.day, sourceSpec: spec, provider: .astronomy, confidence: .canonical, notes: $0.notes) }
    }

    // MARK: - CalendarEngine

    public func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .indianPanchangaDefault else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard (1...12).contains(spec.month), (1...30).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }
        guard year >= supportedRange.lowerBound.year, year <= supportedRange.upperBound.year else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }
        let (loc, defaulted) = try resolvedLocation(spec.calculationLocation)

        let matches = try scan(year: year, location: loc, defaulted: defaulted) {
            $0.masa == spec.month && $0.tithi == spec.day
                && (spec.isLeapMonth == nil || $0.isAdhikaMasa == spec.isLeapMonth)
        }
        var occurrences: [CalendarOccurrence] = []
        occurrences.reserveCapacity(matches.count)
        for match in matches {
            occurrences.append(
                CalendarOccurrence(
                    day: match.day,
                    sourceSpec: spec,
                    provider: .astronomy,
                    confidence: .canonical,
                    notes: match.notes
                )
            )
        }
        return occurrences
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        guard supportedRange.contains(gregorianDay) else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        let p = try panchanga(for: gregorianDay, location: defaultLocation)
        return CalendarDateSpec(
            system: .indianPanchanga,
            variant: .indianPanchangaDefault,
            year: nil,
            month: p.masa,
            day: p.tithi,
            isLeapMonth: p.isAdhikaMasa,
            dayBoundary: .sunrise,
            calculationLocation: defaultLocation
        )
    }

    // MARK: - Scan

    private struct Match { var day: GregorianDay
        var notes: [OccurrenceNote]
    }

    private func scan(
        year: Int,
        location: CalculationLocation,
        defaulted: Bool,
        where predicate: (Panchanga) -> Bool
    ) throws -> [Match] {
        var raw: [GregorianDay] = []
        raw.reserveCapacity(16)
        var day = GregorianDay(year: year, month: 1, day: 1)!
        let end = GregorianDay(year: year, month: 12, day: 31)!
        do {
            while day <= end {
                let tz = tzHours(location, on: day)
                if let p = try calculator.panchanga(civilDay: day, location: location, timeZoneHours: tz), predicate(p) {
                    raw.append(day)
                }
                day = day.adding(days: 1)
            }
        } catch is Astronomy.OutOfRange {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: year)
        }

        var result: [Match] = []
        result.reserveCapacity(raw.count)
        for (index, d) in raw.enumerated() {
            var notes: [OccurrenceNote] = []
            if defaulted { notes.append(.locationDefaulted) }
            // Two consecutive matching sunrises mean the limb spanned two days.
            let consecutive = (index > 0 && d.days(since: raw[index - 1]) == 1)
                || (index < raw.count - 1 && raw[index + 1].days(since: d) == 1)
            if consecutive { notes.append(.repeatedTithi) }
            result.append(Match(day: d, notes: notes))
        }
        return result
    }

    private func resolvedLocation(_ location: CalculationLocation?) throws -> (CalculationLocation, Bool) {
        let loc = location ?? defaultLocation
        guard loc.latitude != nil, loc.longitude != nil else {
            throw CalendarEngineError.requiresLocation(system: system)
        }
        return (loc, location == nil)
    }

    private func tzHours(_ location: CalculationLocation, on day: GregorianDay) -> Double {
        if let id = location.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = tz
            if let date = gregorian.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) {
                return Double(tz.secondsFromGMT(for: date)) / 3600.0
            }
        }
        // Fall back to a longitude-based mean offset.
        return (location.longitude ?? 0) / 15.0
    }
}
