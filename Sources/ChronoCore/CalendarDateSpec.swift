public struct CalendarDateSpec: Codable, Hashable, Sendable {
    public var system: CalendarSystem
    public var variant: CalendarVariant
    public var era: String?
    public var year: Int?
    public var month: Int
    public var day: Int
    public var isLeapMonth: Bool?
    public var dayBoundary: DayBoundary
    public var recurrencePolicy: RecurrencePolicy
    public var calculationLocation: CalculationLocation?

    public init(
        system: CalendarSystem,
        variant: CalendarVariant,
        era: String? = nil,
        year: Int?,
        month: Int,
        day: Int,
        isLeapMonth: Bool? = nil,
        dayBoundary: DayBoundary = .engineDefault,
        recurrencePolicy: RecurrencePolicy = .engineDefault,
        calculationLocation: CalculationLocation? = nil
    ) {
        self.system = system
        self.variant = variant
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
        self.dayBoundary = dayBoundary
        self.recurrencePolicy = recurrencePolicy
        self.calculationLocation = calculationLocation
    }

    private enum CodingKeys: String, CodingKey {
        case system, variant, era, year, month, day
        case isLeapMonth, dayBoundary, recurrencePolicy, calculationLocation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        system = try c.decode(CalendarSystem.self, forKey: .system)
        variant = try c.decode(CalendarVariant.self, forKey: .variant)
        era = try c.decodeIfPresent(String.self, forKey: .era)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        month = try c.decode(Int.self, forKey: .month)
        day = try c.decode(Int.self, forKey: .day)
        isLeapMonth = try c.decodeIfPresent(Bool.self, forKey: .isLeapMonth)
        dayBoundary = try c.decodeIfPresent(DayBoundary.self, forKey: .dayBoundary) ?? .engineDefault
        recurrencePolicy = try c.decodeIfPresent(RecurrencePolicy.self, forKey: .recurrencePolicy) ?? .engineDefault
        calculationLocation = try c.decodeIfPresent(CalculationLocation.self, forKey: .calculationLocation)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(system, forKey: .system)
        try c.encode(variant, forKey: .variant)
        try c.encodeIfPresent(era, forKey: .era)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encode(month, forKey: .month)
        try c.encode(day, forKey: .day)
        try c.encodeIfPresent(isLeapMonth, forKey: .isLeapMonth)
        try c.encode(dayBoundary, forKey: .dayBoundary)
        try c.encode(recurrencePolicy, forKey: .recurrencePolicy)
        try c.encodeIfPresent(calculationLocation, forKey: .calculationLocation)
    }
}
