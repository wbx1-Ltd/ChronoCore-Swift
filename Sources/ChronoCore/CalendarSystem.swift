public enum CalendarSystem: String, CaseIterable, Codable, Hashable, Sendable {
    case gregorian
    case chineseLunar
    case koreanLunisolar
    case vietnameseLunisolar
    case hebrew
    case hijriUmmAlQura
    case nepaliBikramSambat
    case indianPanchanga
    case bangla
}
