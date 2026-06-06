import ChronoCore
import ChronoCoreAstronomy
import ChronoCoreFoundation
import ChronoCoreLunarCoreAdapter
import ChronoCoreTables
import XCTest

final class EngineRegistryTests: XCTestCase {
    private func fullRegistry() -> CalendarEngineRegistry {
        CalendarEngineRegistry(engines: [
            GregorianEngine(),
            ChineseLunarEngine(),
            HebrewEngine(),
            HijriUmmAlQuraEngine(),
            KoreanLunisolarEngine(),
            VietnameseLunisolarEngine(),
            IndianPanchangaEngine(),
            NepaliBikramSambatEngine(),
            BanglaEngine()
        ])
    }

    func testEverySystemHasAnEngine() {
        let registry = fullRegistry()
        for system in CalendarSystem.allCases {
            let engine = registry.engine(for: system)
            XCTAssertNotNil(engine, "no engine for \(system)")
            XCTAssertEqual(engine?.system, system)
        }
        XCTAssertEqual(registry.registeredSystems.count, CalendarSystem.allCases.count)
    }

    func testAllCapabilitiesImplemented() {
        for capability in fullRegistry().capabilities() {
            XCTAssertTrue(capability.isImplemented, "\(capability.system) not implemented")
            XCTAssertFalse(capability.supportedVariants.isEmpty, "\(capability.system) has no variants")
            XCTAssertFalse(capability.providerDataVersion.isEmpty)
            XCTAssertNotNil(capability.supportedGregorianRange, "\(capability.system) missing range")
        }
    }

    func testValidatedSystems() {
        // Foundation, dependency, astronomy lunisolar, and Bangla are validated;
        // Panchanga and Nepali are honest about pending official cross-checks.
        let caps = Dictionary(uniqueKeysWithValues: fullRegistry().capabilities().map { ($0.system, $0) })
        for s in [CalendarSystem.gregorian, .chineseLunar, .hebrew, .hijriUmmAlQura, .koreanLunisolar, .vietnameseLunisolar, .bangla] {
            XCTAssertTrue(caps[s]?.isValidated ?? false, "\(s) should be validated")
        }
        XCTAssertEqual(caps[.indianPanchanga]?.isValidated, false)
        XCTAssertEqual(caps[.nepaliBikramSambat]?.isValidated, false)
    }

    func testFingerprintUniquePerSystem() {
        let registry = fullRegistry()
        var keys: Set<String> = []
        for system in CalendarSystem.allCases {
            guard let engine = registry.engine(for: system) else { continue }
            let spec = CalendarDateSpec(system: system, variant: engine.capability.supportedVariants[0], year: nil, month: 1, day: 1)
            keys.insert(engine.fingerprint(for: spec).cacheKey)
        }
        XCTAssertEqual(keys.count, CalendarSystem.allCases.count, "fingerprints must differ per system")
    }
}
