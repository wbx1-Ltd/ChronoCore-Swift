/// A lookup of calendar engines by system. Core ships only the Gregorian engine;
/// engines from other targets are registered by the consumer (or by assembling a
/// registry in tests), keeping target boundaries clean.
public struct CalendarEngineRegistry: Sendable {
    private var engines: [CalendarSystem: any CalendarEngine]

    public init(engines: [any CalendarEngine] = [GregorianEngine()]) {
        var map: [CalendarSystem: any CalendarEngine] = [:]
        for engine in engines {
            map[engine.system] = engine
        }
        self.engines = map
    }

    public mutating func register(_ engine: any CalendarEngine) {
        engines[engine.system] = engine
    }

    public func registering(_ engine: any CalendarEngine) -> CalendarEngineRegistry {
        var copy = self
        copy.register(engine)
        return copy
    }

    public func engine(for system: CalendarSystem) -> (any CalendarEngine)? {
        engines[system]
    }

    public var registeredSystems: [CalendarSystem] {
        engines.keys.sorted { $0.rawValue < $1.rawValue }
    }

    public func capabilities() -> [CalendarSystemCapability] {
        registeredSystems.compactMap { engines[$0]?.capability }
    }
}
