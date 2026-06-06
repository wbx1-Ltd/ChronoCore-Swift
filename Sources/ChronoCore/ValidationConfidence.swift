public enum ValidationConfidence: String, CaseIterable, Codable, Hashable, Sendable {
    case canonical
    case providerVerified
    case unchecked
}
