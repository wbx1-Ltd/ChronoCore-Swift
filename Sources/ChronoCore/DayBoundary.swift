public enum DayBoundary: Codable, Hashable, Sendable {
    case engineDefault
    case civilMidnight(timeZoneIdentifier: String)
    case sunset(bornAfterSunset: Bool?)
    case sunrise

    private enum CodingKeys: String, CodingKey {
        case kind
        case timeZoneIdentifier
        case bornAfterSunset
    }

    private enum Kind: String, Codable {
        case engineDefault
        case civilMidnight
        case sunset
        case sunrise
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let rawValue = try? single.decode(String.self),
           let kind = Kind(rawValue: rawValue)
        {
            switch kind {
            case .engineDefault:
                self = .engineDefault
            case .sunrise:
                self = .sunrise
            case .civilMidnight:
                self = .civilMidnight(timeZoneIdentifier: "UTC")
            case .sunset:
                self = .sunset(bornAfterSunset: nil)
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .engineDefault:
            self = .engineDefault
        case .civilMidnight:
            self = try .civilMidnight(
                timeZoneIdentifier: container.decode(String.self, forKey: .timeZoneIdentifier)
            )
        case .sunset:
            self = try .sunset(
                bornAfterSunset: container.decodeIfPresent(Bool.self, forKey: .bornAfterSunset)
            )
        case .sunrise:
            self = .sunrise
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .engineDefault:
            var container = encoder.singleValueContainer()
            try container.encode(Kind.engineDefault.rawValue)
        case .sunrise:
            var container = encoder.singleValueContainer()
            try container.encode(Kind.sunrise.rawValue)
        case .civilMidnight(let timeZoneIdentifier):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Kind.civilMidnight, forKey: .kind)
            try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        case .sunset(let bornAfterSunset):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Kind.sunset, forKey: .kind)
            try container.encodeIfPresent(bornAfterSunset, forKey: .bornAfterSunset)
        }
    }
}
