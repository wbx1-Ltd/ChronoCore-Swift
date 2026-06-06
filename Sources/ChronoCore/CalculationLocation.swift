public struct CalculationLocation: Codable, Hashable, Sendable {
    public var identifier: String?
    public var latitude: Double?
    public var longitude: Double?
    public var timeZoneIdentifier: String?

    public init(
        identifier: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timeZoneIdentifier: String? = nil
    ) {
        self.identifier = identifier
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}
