public struct CalendarOccurrence: Codable, Hashable, Sendable {
    public var day: GregorianDay
    public var sourceSpec: CalendarDateSpec
    public var provider: EngineProviderKind
    public var confidence: ValidationConfidence
    public var notes: [OccurrenceNote]

    public init(
        day: GregorianDay,
        sourceSpec: CalendarDateSpec,
        provider: EngineProviderKind,
        confidence: ValidationConfidence = .canonical,
        notes: [OccurrenceNote] = []
    ) {
        self.day = day
        self.sourceSpec = sourceSpec
        self.provider = provider
        self.confidence = confidence
        self.notes = notes
    }
}
