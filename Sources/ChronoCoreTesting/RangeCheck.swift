import ChronoCore

/// Helpers for large-range round-trip and monotonicity checks. Pure; the test
/// target asserts on the returned report.
public enum RangeCheck {
    public struct RoundTripReport: Equatable, Sendable {
        public var checked: Int
        public var failures: [Failure]
        public var isClean: Bool { failures.isEmpty }

        public struct Failure: Equatable, Sendable {
            public var day: GregorianDay
            public var detail: String
        }
    }

    /// For every Gregorian day in the range, maps day -> spec and then asserts the
    /// engine reproduces that same day among the occurrences of the recovered spec
    /// in the day's Gregorian year. Confirms round-trip stability.
    public static func roundTrip(
        engine: any CalendarEngine,
        from: GregorianDay,
        to: GregorianDay,
        step: Int = 1
    ) -> RoundTripReport {
        guard step > 0 else {
            return RoundTripReport(
                checked: 0,
                failures: [.init(day: from, detail: "step must be greater than zero")]
            )
        }
        var failures: [RoundTripReport.Failure] = []
        var checked = 0
        var jdn = from.julianDayNumber
        let end = to.julianDayNumber
        while jdn <= end {
            let day = GregorianDay(julianDayNumber: jdn)
            checked += 1
            do {
                let spec = try engine.dateSpec(from: day)
                let back = try engine.occurrences(of: spec, inGregorianYear: day.year).map(\.day)
                if !back.contains(day) {
                    failures.append(.init(day: day, detail: "spec \(spec.month)/\(spec.day) did not reproduce day; got \(back.map(\.description))"))
                }
            } catch {
                failures.append(.init(day: day, detail: "threw \(error)"))
            }
            jdn += step
        }
        return RoundTripReport(checked: checked, failures: failures)
    }

    /// Confirms occurrences across a year span are strictly increasing with no
    /// duplicates for a yearless spec.
    public static func isMonotonic(_ days: [GregorianDay]) -> Bool {
        guard days.count > 1 else { return true }
        for i in 1..<days.count where days[i] <= days[i - 1] {
            return false
        }
        return true
    }
}
