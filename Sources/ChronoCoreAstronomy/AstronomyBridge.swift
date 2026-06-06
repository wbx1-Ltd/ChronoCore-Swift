import AstroCore
import ChronoCore
import Foundation

/// Bridges ChronoCore to AstroCore high-precision Sun and Moon positions.
/// AstroCore CivilMoment supports Gregorian years 1800...2100, which caps the
/// astronomy engines accordingly.
enum AstronomyBridge {
    static let supportedYearRange: ClosedRange<Int> = 1800...2100
}
