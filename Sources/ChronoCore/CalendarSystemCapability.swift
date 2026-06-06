/// Describes what a calendar engine can do. Release status is expressed here,
/// not by the presence of a CalendarSystem case.
public struct CalendarSystemCapability: Codable, Hashable, Sendable {
    public var system: CalendarSystem
    public var isImplemented: Bool
    public var isValidated: Bool
    public var supportedGregorianRange: ClosedRange<GregorianDay>?
    public var requiresLocation: Bool
    public var supportsYearlessRecurrence: Bool
    public var defaultProvider: EngineProviderKind
    public var providerDataVersion: String
    public var supportedVariants: [CalendarVariant]
    // Hints for downstream targets (watch, widget, extension) per design 10.4.
    public var isHeavy: Bool
    public var extensionSafe: Bool

    public init(
        system: CalendarSystem,
        isImplemented: Bool,
        isValidated: Bool,
        supportedGregorianRange: ClosedRange<GregorianDay>?,
        requiresLocation: Bool,
        supportsYearlessRecurrence: Bool,
        defaultProvider: EngineProviderKind,
        providerDataVersion: String,
        supportedVariants: [CalendarVariant],
        isHeavy: Bool = false,
        extensionSafe: Bool = true
    ) {
        self.system = system
        self.isImplemented = isImplemented
        self.isValidated = isValidated
        self.supportedGregorianRange = supportedGregorianRange
        self.requiresLocation = requiresLocation
        self.supportsYearlessRecurrence = supportsYearlessRecurrence
        self.defaultProvider = defaultProvider
        self.providerDataVersion = providerDataVersion
        self.supportedVariants = supportedVariants
        self.isHeavy = isHeavy
        self.extensionSafe = extensionSafe
    }
}
