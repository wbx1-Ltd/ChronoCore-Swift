import Foundation

public struct GregorianDayDateAdapter: Sendable {
    public var calendar: Calendar
    public var timeZone: TimeZone

    public init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.timeZone = timeZone
    }

    public func date(for day: GregorianDay) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }
}
