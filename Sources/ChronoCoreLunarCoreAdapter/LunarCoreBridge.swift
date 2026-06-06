import ChronoCore
import LunarCore

/// Bridges ChronoCore to the LunarCore Chinese lunar engine.
enum LunarCoreBridge {
    static let supportedYearRange: ClosedRange<Int> = LunarCalendar.shared.supportedYearRange
}
