import ChronoCore
import Foundation

/// Shared helpers for Foundation-backed calendar providers.
/// Engines in this target use ICU-backed Foundation calendars as their
/// canonical provider, gated by availability where required.
enum FoundationProviderSupport {
    /// UTC Gregorian calendar used to build and read date-only components.
    static let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
