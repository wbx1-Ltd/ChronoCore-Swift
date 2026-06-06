import ChronoCore

/// Nepali Bikram Sambat engine. Table driven and deterministic; no astronomy at
/// runtime. The embedded table (see NepaliBikramSambatData) maps BS dates to
/// Gregorian by accumulating month lengths from a fixed anchor. Foundation
/// .vikram is the Indian Vikram Samvat and is not used here.
public struct NepaliBikramSambatEngine: CalendarEngine {
    public let system: CalendarSystem = .nepaliBikramSambat

    private let table = NepaliBikramSambatData.monthLengths
    private let startYear = NepaliBikramSambatData.startBSYear
    private let anchorJDN: Int
    private let yearStartOffsets: [Int]
    private let monthStartOffsets: [[Int]]
    private let totalDays: Int

    public init() {
        let a = NepaliBikramSambatData.anchorGregorian
        anchorJDN = GregorianDay(year: a.year, month: a.month, day: a.day)!.julianDayNumber
        let table = NepaliBikramSambatData.monthLengths
        yearStartOffsets = Self.makeYearStartOffsets(table: table)
        monthStartOffsets = Self.makeMonthStartOffsets(table: table)
        totalDays = yearStartOffsets.last ?? 0
    }

    private var endYear: Int { startYear + table.count - 1 }

    public var capability: CalendarSystemCapability {
        let lower = GregorianDay(julianDayNumber: anchorJDN)
        let upper = GregorianDay(julianDayNumber: anchorJDN + totalDays - 1)
        return CalendarSystemCapability(
            system: .nepaliBikramSambat,
            isImplemented: true,
            // Canonical civil Bikram Sambat table, verified against known civil
            // New Year anchors over the full range.
            isValidated: true,
            supportedGregorianRange: lower...upper,
            requiresLocation: false,
            supportsYearlessRecurrence: true,
            defaultProvider: .table,
            providerDataVersion: "nepali-bs-civil-\(startYear)-\(endYear)",
            supportedVariants: [.nepaliOfficial]
        )
    }

    public func occurrences(of spec: CalendarDateSpec, inGregorianYear year: Int) throws -> [CalendarOccurrence] {
        guard spec.system == system else {
            throw CalendarEngineError.unsupportedSystem(spec.system)
        }
        guard spec.variant == .nepaliOfficial else {
            throw CalendarEngineError.unsupportedVariant(spec.variant)
        }
        guard (1...12).contains(spec.month), (1...32).contains(spec.day) else {
            throw CalendarEngineError.invalidDate(system: system, month: spec.month, day: spec.day)
        }

        let candidateBSYears: [Int] = if let bsYear = spec.year {
            [bsYear]
        } else {
            // BS is about Gregorian + 56 or 57.
            [year + 56, year + 57]
        }

        var results: [CalendarOccurrence] = []
        for bsYear in candidateBSYears {
            guard let resolved = resolve(bsYear: bsYear, month: spec.month, day: spec.day, spec: spec) else { continue }
            if resolved.day.year == year {
                results.append(resolved)
            }
        }
        return results.sorted { $0.day < $1.day }
    }

    public func dateSpec(from gregorianDay: GregorianDay) throws -> CalendarDateSpec {
        let offset = gregorianDay.julianDayNumber - anchorJDN
        guard offset >= 0, offset < totalDays else {
            throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
        }
        let index = yearIndex(containingOffset: offset)
        let offsetWithinYear = offset - yearStartOffsets[index]
        let monthOffsets = monthStartOffsets[index]
        for monthIndex in 0..<12 where offsetWithinYear < monthOffsets[monthIndex + 1] {
            return CalendarDateSpec(
                system: .nepaliBikramSambat,
                variant: .nepaliOfficial,
                year: startYear + index,
                month: monthIndex + 1,
                day: offsetWithinYear - monthOffsets[monthIndex] + 1,
                dayBoundary: .civilMidnight(timeZoneIdentifier: "Asia/Kathmandu")
            )
        }
        throw CalendarEngineError.outOfSupportedRange(system: system, year: gregorianDay.year)
    }

    // MARK: - Helpers

    private func resolve(bsYear: Int, month: Int, day: Int, spec: CalendarDateSpec) -> CalendarOccurrence? {
        let index = bsYear - startYear
        guard index >= 0, index < table.count else { return nil }
        let lengths = table[index]
        let monthLength = lengths[month - 1]
        var notes: [OccurrenceNote] = []
        var effectiveDay = day
        if day > monthLength {
            guard spec.recurrencePolicy == .engineDefault || spec.recurrencePolicy == .nearestValidDay else {
                return nil
            }
            effectiveDay = monthLength
            notes.append(.monthLengthClamped)
        }
        var offset = yearStartOffsets[index]
        offset += monthStartOffsets[index][month - 1]
        offset += effectiveDay - 1
        let day = GregorianDay(julianDayNumber: anchorJDN + offset)
        return CalendarOccurrence(day: day, sourceSpec: spec, provider: .table, confidence: .canonical, notes: notes)
    }

    private static func makeYearStartOffsets(table: [[Int]]) -> [Int] {
        var offsets: [Int] = []
        offsets.reserveCapacity(table.count + 1)
        var running = 0
        offsets.append(running)
        for lengths in table {
            running += lengths.reduce(0, +)
            offsets.append(running)
        }
        return offsets
    }

    private static func makeMonthStartOffsets(table: [[Int]]) -> [[Int]] {
        table.map { lengths in
            var offsets: [Int] = []
            offsets.reserveCapacity(lengths.count + 1)
            var running = 0
            offsets.append(running)
            for length in lengths {
                running += length
                offsets.append(running)
            }
            return offsets
        }
    }

    private func yearIndex(containingOffset offset: Int) -> Int {
        var low = 0
        var high = yearStartOffsets.count - 1
        while low + 1 < high {
            let mid = (low + high) / 2
            if yearStartOffsets[mid] <= offset {
                low = mid
            } else {
                high = mid
            }
        }
        return low
    }
}
