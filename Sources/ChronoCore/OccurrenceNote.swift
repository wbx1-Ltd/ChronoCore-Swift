/// Controlled vocabulary of audit notes attached to an occurrence. Stable raw
/// values keep notes serializable, localizable, and reviewable rather than free
/// text.
public enum OccurrenceNote: String, CaseIterable, Codable, Hashable, Sendable {
    // Gregorian and generic recurrence.
    case adjustedToNearestValidDay
    case skippedInvalidDate
    case monthLengthClamped

    // Location and provider.
    case requiresLocation
    case locationDefaulted
    case providerParityUnchecked
    case providerVerified

    // Lunisolar leap handling (Chinese, Korean, Vietnamese).
    case leapMonthFallbackToRegular
    case leapMonthOnlyNoMatch
    case regularMonthRequestedButLeapExists

    // Hebrew Adar handling.
    case adarMappedToAdarII
    case adarMappedToAdar
    case adarRecurrenceAmbiguous

    // Sunset and sunrise boundaries.
    case bornAfterSunsetUnspecified
    case dayAdvancedForSunset
    case sunsetBoundaryApproximate

    // Panchanga tithi behaviour.
    case repeatedTithi
    case skippedTithi

    /// Versioned historical rules (Bangla pre-reform).
    case historicalRuleVersion
}
