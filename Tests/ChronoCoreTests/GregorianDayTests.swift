@testable import ChronoCore
import XCTest

final class GregorianDayTests: XCTestCase {
    func testValidatesCivilGregorianDates() {
        XCTAssertNil(GregorianDay(year: 2023, month: 2, day: 29))
        XCTAssertNil(GregorianDay(year: 2026, month: 13, day: 1))
        XCTAssertNil(GregorianDay(year: 2026, month: 0, day: 1))
        XCTAssertNil(GregorianDay(year: 2026, month: 1, day: 0))

        let leapDay = GregorianDay(year: 2024, month: 2, day: 29)
        XCTAssertEqual(leapDay?.year, 2024)
        XCTAssertEqual(leapDay?.month, 2)
        XCTAssertEqual(leapDay?.day, 29)
        XCTAssertEqual(leapDay?.description, "2024-02-29")
    }

    func testOrdersByYearMonthDay() throws {
        let january = try XCTUnwrap(GregorianDay(year: 2026, month: 1, day: 1))
        let march = try XCTUnwrap(GregorianDay(year: 2026, month: 3, day: 1))
        let nextYear = try XCTUnwrap(GregorianDay(year: 2027, month: 1, day: 1))

        XCTAssertLessThan(january, march)
        XCTAssertLessThan(march, nextYear)
    }
}
