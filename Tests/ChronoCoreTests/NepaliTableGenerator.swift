import ChronoCore
@testable import ChronoCoreAstronomy
import XCTest

/// Independent astronomical cross-check for the Nepali Bikram Sambat engine. The
/// embedded table (NepaliBikramSambatData) is the canonical civil dataset; this
/// asserts that Lahiri sidereal solar ingress at the Kathmandu meridian
/// (UTC+5:45) reproduces the known civil New Year anchors, confirming the year
/// boundaries from first principles. It also prints the astronomical month-length
/// table for reference. Gated by CHRONO_GEN=1 (the CI baseline job) and skipped
/// by default because it depends on the astronomy stack.
final class NepaliTableGenerator: XCTestCase {
    private let tzHours = 5.75 // Asia/Kathmandu

    func testGenerate() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHRONO_GEN"] == "1", "generator")
        var lines: [String] = []
        for bsYear in 2000...2110 {
            let lengths = try monthLengths(bsYear: bsYear)
            lines.append("        [\(lengths.map(String.init).joined(separator: ", "))], // BS \(bsYear)")
        }
        print("NEPALI_TABLE_BEGIN")
        print(lines.joined(separator: "\n"))
        print("NEPALI_TABLE_END")

        // Assert the astronomical New Year matches the known civil anchors.
        for (bs, g) in [(2000, (1943, 4, 14)), (2076, (2019, 4, 14)), (2080, (2023, 4, 14)), (2081, (2024, 4, 13)), (2082, (2025, 4, 14))] {
            let ny = try newYearCivilDay(bsYear: bs)
            let expected = GregorianDay(year: g.0, month: g.1, day: g.2)
            XCTAssertEqual(ny, expected, "astronomical New Year for BS \(bs)")
        }
    }

    private func monthLengths(bsYear: Int) throws -> [Int] {
        var starts: [Int] = []
        for i in 0...12 {
            try starts.append(ingressCivilDay(bsYear: bsYear, monthIndex: i))
        }
        return (0..<12).map { starts[$0 + 1] - starts[$0] }
    }

    private func newYearCivilDay(bsYear: Int) throws -> GregorianDay {
        try GregorianDay(julianDayNumber: ingressCivilDay(bsYear: bsYear, monthIndex: 0))
    }

    /// Civil day (Kathmandu) of the sidereal solar ingress into sign monthIndex
    /// for the given BS year. monthIndex 0 = Mesha (Baishakh start).
    private func ingressCivilDay(bsYear: Int, monthIndex: Int) throws -> Int {
        let gregYear = bsYear - 57
        let target = Double(monthIndex % 12) * 30.0
        let approxJDN = GregorianDay(year: gregYear, month: 4, day: 14)!.julianDayNumber
        let nearJD = Double(approxJDN) + Double(monthIndex) * 30.4368
        let jd = try ingressJD(target: target, nearJD: nearJD)
        return Int((jd + 0.5 + tzHours / 24.0).rounded(.down))
    }

    private func ingressJD(target: Double, nearJD: Double) throws -> Double {
        func f(_ jd: Double) throws -> Double {
            let tropical = try Astronomy.sunLongitude(julianDay: jd)
            var s = (tropical - Ayanamsa.lahiri(julianDay: jd) - target).truncatingRemainder(dividingBy: 360)
            if s > 180 { s -= 360 }
            if s < -180 { s += 360 }
            return s
        }
        var lo = nearJD - 25
        var hi = nearJD + 25
        var flo = try f(lo)
        // Scan for the upward zero crossing.
        var step = lo + 1
        while step <= hi {
            let fs = try f(step)
            if flo < 0 && fs >= 0 { lo = step - 1
                hi = step
                break
            }
            flo = fs
            step += 1
        }
        for _ in 0..<50 {
            let mid = (lo + hi) / 2
            if abs(hi - lo) < 1e-6 { return mid }
            let fm = try f(mid)
            if fm < 0 { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}
