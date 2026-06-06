public enum RecurrencePolicy: String, CaseIterable, Codable, Hashable, Sendable {
    case engineDefault
    case exactMonthDay
    case leapMonthOnly
    case nonLeapMonthOnly
    case nearestValidDay
    case skipIfAmbiguous
    case userDefined
}
