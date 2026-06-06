public struct GregorianDay: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard Self.isValid(year: year, month: month, day: day) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public var description: String {
        "\(year)-\(Self.twoDigits(month))-\(Self.twoDigits(day))"
    }

    public static func < (lhs: GregorianDay, rhs: GregorianDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        if year.isMultiple(of: 400) { return true }
        if year.isMultiple(of: 100) { return false }
        return year.isMultiple(of: 4)
    }

    public static func daysInMonth(_ month: Int, year: Int) -> Int? {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            31
        case 4, 6, 9, 11:
            30
        case 2:
            isLeapYear(year) ? 29 : 28
        default:
            nil
        }
    }

    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard let daysInMonth = daysInMonth(month, year: year) else {
            return false
        }
        return (1...daysInMonth).contains(day)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private enum CodingKeys: String, CodingKey {
        case year
        case month
        case day
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decode(Int.self, forKey: .month)
        let day = try container.decode(Int.self, forKey: .day)
        guard let value = GregorianDay(year: year, month: month, day: day) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid Gregorian day \(year)-\(month)-\(day)."
                )
            )
        }
        self = value
    }
}
