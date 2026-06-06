import ChronoCore
import ChronoCoreTesting
import XCTest

/// Shared helpers for fixture-driven tests.
enum FixtureHarness {
    static func fixtures(_ name: String) throws -> [GoldenFixture] {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "missing fixture resource \(name).json"
        )
        return try GoldenFixture.loadArray(from: url)
    }

    static func assertAll(
        _ name: String,
        engine: any CalendarEngine,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let all = try fixtures(name)
        XCTAssertFalse(all.isEmpty, "fixture file \(name).json is empty", file: file, line: line)
        for fixture in all {
            let evaluation = try FixtureRunner.evaluate(fixture, with: engine)
            XCTAssertTrue(evaluation.matches, evaluation.failureMessage, file: file, line: line)
        }
    }
}
