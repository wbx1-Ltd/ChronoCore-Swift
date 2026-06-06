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
        // Every system is validated against an authoritative source: ICU for the
        // Foundation engines, LunarCore for Chinese, Foundation .dangi/.vietnamese
        // for the lunisolar engines, the canonical civil table for Nepali, the
        // reform anchors for Bangla, and Drik Panchang for Indian Panchanga.
        let caps = Dictionary(uniqueKeysWithValues: fullRegistry().capabilities().map { ($0.system, $0) })
        for system in CalendarSystem.allCases {
            XCTAssertEqual(caps[system]?.isValidated, true, "\(system) should be validated")
        }
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
