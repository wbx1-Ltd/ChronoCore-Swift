import ChronoCore
import Foundation
import XCTest

/// Compares an astronomy lunisolar engine against a Foundation calendar oracle by
/// walking every civil day of the given years and matching month, day, and leap
/// flag. Foundation .dangi and .vietnamese are authoritative for these systems.
enum LunisolarParity {
    static func assert(
        engine: any CalendarEngine,
        identifier: Calendar.Identifier,
        timeZone tz: String,
        years: [Int],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: tz)!
        var oracle = Calendar(identifier: identifier)
        oracle.timeZone = TimeZone(identifier: tz)!

        var mismatches: [String] = []
        var compared = 0
        for year in years {
            var day = GregorianDay(year: year, month: 1, day: 1)!
            let end = GregorianDay(year: year, month: 12, day: 31)!
            while day <= end {
                let date = gregorian.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
                let dc = oracle.dateComponents([.month, .day, .isLeapMonth], from: date)
                do {
                    let spec = try engine.dateSpec(from: day)
                    let leap = spec.isLeapMonth ?? false
                    if dc.month != spec.month || dc.day != spec.day || (dc.isLeapMonth ?? false) != leap {
                        if mismatches.count < 8 {
                            mismatches.append("\(day): engine \(spec.month)/\(spec.day) leap=\(leap) vs oracle \(dc.month ?? -1)/\(dc.day ?? -1) leap=\(dc.isLeapMonth ?? false)")
                        }
                    }
                    compared += 1
                } catch {
                    mismatches.append("\(day): threw \(error)")
                }
                day = day.adding(days: 1)
            }
        }
        XCTAssertGreaterThan(compared, 0, file: file, line: line)
        XCTAssertTrue(mismatches.isEmpty, "lunisolar parity mismatches (\(mismatches.count) shown): \(mismatches)", file: file, line: line)
    }
}
