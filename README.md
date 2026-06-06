<div align="center"><a name="readme-top"></a>

# ChronoCore

A date-only calendar conversion, recurrence, and validation core in pure Swift.<br/>
Built for civil and traditional calendar systems: provider-agnostic, fixture-verified, thread-safe.

[简体中文](./README.zh-CN.md) · [Report Issue][github-issues-link] · [Releases][github-release-link]

<!-- SHIELD GROUP -->

[![][github-stars-shield]][github-stars-link]
[![][github-forks-shield]][github-forks-link]
[![][github-issues-shield]][github-issues-link]
[![][github-license-shield]][github-license-link]<br/>
[![][github-contributors-shield]][github-contributors-link]

</div>

<details>
<summary><kbd>Table of Contents</kbd></summary>

#### TOC

- [✨ Features](#-features)
- [🧠 Design](#-design)
- [📦 Installation](#-installation)
- [🚀 Usage](#-usage)
  - [📅 Date-Only Days](#-date-only-days)
  - [🔁 Recurrence](#-recurrence)
  - [🪂 Leap-Day Policy](#-leap-day-policy)
  - [📆 Date Ranges](#-date-ranges)
  - [🔄 Round-Trip](#-round-trip)
  - [🕐 Foundation.Date Interop](#-foundationdate-interop)
  - [🧪 Golden Fixtures](#-golden-fixtures)
- [🧩 Calendar Systems](#-calendar-systems)
- [🧪 Testing](#-testing)
- [🗂️ API Reference](#️-api-reference)
- [📋 Platform Support](#-platform-support)
- [📝 License](#-license)

####

<br/>

</details>

## ✨ Features

> \[!IMPORTANT\]
>
> **Star Us** to receive all release notifications from GitHub without any delay \~ ⭐️

| | Feature | Description |
|-|---------|-------------|
| 📅 | **Date-Only Model** | `GregorianDay` value type, validated at construction, `Comparable`, `Codable`, no time-of-day ambiguity |
| 🔁 | **Recurrence** | Yearless specs expand into occurrences for a single year or a closed day range |
| 🪂 | **Leap-Day Policy** | Feb 29 fallback strategies: skip silently or adjust to the nearest valid day with a note |
| 🧭 | **Day Boundary Model** | Civil midnight, sunset, or sunrise; the boundary travels with the request, not the engine |
| 🧱 | **Provider-Agnostic Engine** | `CalendarEngine` protocol: swap algorithmic, Foundation, table, or astronomy backends |
| 🏷️ | **Provenance Tracking** | Every occurrence records its provider, validation confidence, and structured notes |
| 🌍 | **Calculation Location** | Optional latitude / longitude / timezone for location-dependent traditional calendars |
| 🌐 | **Nine Calendar Systems** | Gregorian, Chinese, Korean, Vietnamese, Hebrew, Hijri Umm al-Qura, Nepali Bikram Sambat, Indian Panchanga, Bangla |
| 🔭 | **High-Precision Astronomy** | Lunisolar and Panchanga engines use VSOP87D Sun and ELP2000 Moon positions through AstroCore |
| 🧪 | **Golden Fixtures** | `ChronoCoreTesting` loads JSON golden data for cross-engine and cross-provider verification |
| 🧵 | **Thread-Safe** | Full `Sendable` conformance |
| 🧊 | **Layered Targets** | Core stays pure; Foundation, table, astronomy, and dependency backends live in separate modules |

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🧠 Design

ChronoCore solves one problem: turning a calendar date description (civil or traditional) into concrete Gregorian days you can trust, while keeping track of *how* each day was produced.

- **The package is intentionally separate from app code.** Consumers build their own adapters for Contacts, CloudKit, widgets, or sharing formats *on top* of ChronoCore. Those integrations are never dependencies of the core library.
- **A date is a spec, not just numbers.** `CalendarDateSpec` carries the day boundary, recurrence policy, leap-month flag, and calculation location alongside month/day, so the same request means the same thing across every engine.
- **Provenance over guesswork.** Each `CalendarOccurrence` records which provider computed it (`EngineProviderKind`), how confident the result is (`ValidationConfidence`), and any adjustments made (`OccurrenceNote`). Nothing is silently corrected.
- **Algorithms are the source of truth.** Each system has an independent engine behind one protocol, verified against source-backed golden fixtures. Where a platform calendar (ICU through Foundation) is authoritative, it is used and cross-checked; where it is not (or is unavailable on the platform floor), an astronomical or table engine is the canonical provider so the same input yields the same result on every OS version.
- **Capabilities, not flags.** Release status, supported range, validation state, location requirements, and provider data version are described per engine by `CalendarSystemCapability`, not implied by the presence of a `CalendarSystem` case.

> \[!NOTE\]
>
> All nine target calendar systems are implemented and tested. Two engines (Indian Panchanga and Nepali Bikram Sambat) are marked unvalidated in their capability because a line-by-line cross-check against a published authority is still pending; see [Calendar Systems](#-calendar-systems).

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/wbx1-Ltd/ChronoCore-Swift.git", from: "0.1.0"),
]
```

Then add the core as a target dependency:

```swift
.target(
    name: "YourTarget",
    dependencies: ["ChronoCore"]
),
```

`ChronoCoreTesting` ships golden-fixture helpers for your own test target:

```swift
.testTarget(
    name: "YourTargetTests",
    dependencies: ["ChronoCore", "ChronoCoreTesting"]
),
```

Or in Xcode: **File → Add Package Dependencies…** → paste the URL above.

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🚀 Usage

```swift
import ChronoCore

let engine = GregorianEngine()
```

### 📅 Date-Only Days

`GregorianDay` is a validated, ordered, date-only value. Invalid dates fail at construction, with no silent rollover.

```swift
let day = GregorianDay(year: 2026, month: 3, day: 14)!
print(day)                                  // "2026-03-14"
print(GregorianDay.isLeapYear(2024))        // true
print(GregorianDay.daysInMonth(2, year: 2024) ?? 0)  // 29

let invalid = GregorianDay(year: 2025, month: 2, day: 30)  // nil
```

### 🔁 Recurrence

A yearless spec (`year: nil`) recurs every year. Expand it into occurrences for a given Gregorian year.

```swift
let spec = CalendarDateSpec(
    system: .gregorian,
    variant: .standard,
    year: nil,          // yearless, recurs annually
    month: 3,
    day: 14
)

let occurrences = try engine.occurrences(of: spec, inGregorianYear: 2026)
print(occurrences.first!.day)         // 2026-03-14
print(occurrences.first!.provider)    // .algorithmic
print(occurrences.first!.confidence)  // .canonical
```

### 🪂 Leap-Day Policy

Feb 29 only exists in leap years. The `recurrencePolicy` decides what happens otherwise.

```swift
let leapDay = CalendarDateSpec(
    system: .gregorian,
    variant: .standard,
    year: nil,
    month: 2,
    day: 29,
    recurrencePolicy: .nearestValidDay
)

// 2025 has no Feb 29, so it adjusts to Feb 28 and records why
let resolved = try engine.occurrences(of: leapDay, inGregorianYear: 2025)
print(resolved.first!.day)    // 2025-02-28
print(resolved.first!.notes)  // [.adjustedToNearestValidDay]

// The engine default skips an impossible leap day entirely
let skipping = CalendarDateSpec(
    system: .gregorian, variant: .standard, year: nil, month: 2, day: 29
)
print(try engine.occurrences(of: skipping, inGregorianYear: 2025))  // []
```

### 📆 Date Ranges

Expand a recurring spec across a closed day range:

```swift
let range = GregorianDay(year: 2024, month: 1, day: 1)!
        ... GregorianDay(year: 2026, month: 12, day: 31)!

let across = try engine.occurrences(of: spec, in: range)
print(across.map(\.day))  // [2024-03-14, 2025-03-14, 2026-03-14]
```

### 🔄 Round-Trip

Rebuild a spec from a concrete day:

```swift
let rebuilt = try engine.dateSpec(from: GregorianDay(year: 2026, month: 3, day: 14)!)
print(rebuilt.system, rebuilt.month, rebuilt.day)  // gregorian 3 14
```

### 🕐 Foundation.Date Interop

Bridge a `GregorianDay` to a `Foundation.Date` at the start of the day in any timezone:

```swift
import Foundation

let adapter = GregorianDayDateAdapter(
    timeZone: TimeZone(identifier: "Asia/Shanghai")!
)
let date = adapter.date(for: GregorianDay(year: 2026, month: 3, day: 14)!)
// 2026-03-14 00:00:00 in Shanghai
```

### 🧪 Golden Fixtures

`ChronoCoreTesting` decodes JSON golden data so engines can be checked against known-correct days:

```swift
import ChronoCoreTesting

let fixtures = try GoldenFixture.loadArray(from: fixtureURL)
for fixture in fixtures {
    print(fixture.id, fixture.system, fixture.expectedGregorianDays)
}
```

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🧩 Calendar Systems

Every target system has an engine, verified against source-backed golden fixtures. The `Provider` column shows the canonical computation; `Validated` reflects each engine's `CalendarSystemCapability`.

| | System | Engine (module) | Provider | Validated | Range |
|-|--------|-----------------|----------|-----------|-------|
| ✅ | **Gregorian** | `GregorianEngine` (ChronoCore) | algorithmic | Yes | 1600 to 2400 |
| ✅ | **Chinese Lunar** | `ChineseLunarEngine` (LunarCoreAdapter) | dependency (LunarCore) | Yes | 1900 to 2100 |
| ✅ | **Korean Lunisolar** | `KoreanLunisolarEngine` (Astronomy) | astronomy, UTC+9 | Yes | 1900 to 2099 |
| ✅ | **Vietnamese Lunisolar** | `VietnameseLunisolarEngine` (Astronomy) | astronomy, UTC+7 | Yes | 1968 to 2099 |
| ✅ | **Hebrew** | `HebrewEngine` (Foundation) | foundation (ICU) | Yes | 1900 to 2200 |
| ✅ | **Hijri Umm al-Qura** | `HijriUmmAlQuraEngine` (Foundation) | foundation (ICU) | Yes | 1900 to 2100 |
| ✅ | **Nepali Bikram Sambat** | `NepaliBikramSambatEngine` (Tables) | table | Pending | BS 2000 to 2110 |
| ✅ | **Indian Panchanga** | `IndianPanchangaEngine` (Astronomy) | astronomy, Lahiri | Pending | 1900 to 2099 |
| ✅ | **Bangla** | `BanglaEngine` (Tables) | table (revised) | Yes | about 1919 to 2119 |

Each system exposes its standard or regional variants through `CalendarVariant` (for example `chineseMainland`, `koreanModern`, `vietnameseModernUTC7`, `ummAlQuraSaudi`, `bangladeshRevised`). Korean and Vietnamese are computed astronomically (not approximated from the Chinese calendar) and cross-checked against Foundation `.dangi` and `.vietnamese`; documented boundary divergences are recorded in tests. Indian Panchanga returns the full five limbs (tithi, nakshatra, yoga, karana, masa) at sunrise for a location.

> \[!NOTE\]
>
> Pending validation means the engine is implemented and astronomically or anchor verified, but a line-by-line comparison against a published official calendar is still outstanding. This is surfaced honestly through `CalendarSystemCapability.isValidated`.

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🧪 Testing

| Metric | Value |
|--------|-------|
| Test functions | **102** |
| Test suites | **15** |
| Golden fixtures | **45** |

Run the package tests with:

```bash
swift test
```

Coverage:

- ✅ **Per-engine unit tests** for all nine systems: validation, recurrence, leap and boundary handling
- ✅ **Source-backed golden fixtures**: 45 records across nine calendars (festivals, new years, leap months, reform boundaries, multi-result years)
- ✅ **Provider parity**: astronomy engines checked day-by-day against Foundation `.dangi` and `.vietnamese`; Foundation engines checked against ICU; Chinese checked against Foundation `.chinese`
- ✅ **Round-trip and range**: large-range Gregorian round-trip for table engines, multi-year occurrence ranges, monotonicity
- ✅ **Recurrence cardinality**: zero, one, and many occurrences (for example a Hijri date twice in one Gregorian year)
- ✅ **Serialization**: every public `Codable` model round-trips, and every fixture file decodes under the schema
- ✅ **Registry**: every `CalendarSystem` resolves to an engine with a complete capability and a distinct fingerprint

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🗂️ API Reference

### ChronoCore

| Type | Description |
|------|-------------|
| `GregorianDay` | Date-only Gregorian value (year/month/day), validated, `Comparable`, `Codable`, with Julian Day Number arithmetic |
| `CalendarDateSpec` | Full description of a date / recurrence request (system, variant, era, year, month, day, leap flag, boundary, policy, location) |
| `CalendarEngine` | Protocol every calendar engine conforms to |
| `GregorianEngine` | Proleptic Gregorian implementation |
| `CalendarEngineRegistry` | Lookup of engines by system, with assembled capabilities |
| `CalendarOccurrence` | One resolved day plus provenance (provider, confidence, notes) |
| `CalendarSystemCapability` | Per-engine status, range, validation, location need, provider data version, extension hints |
| `CalendarComputationFingerprint` | Stable cache key over engine version, system, variant, spec, boundary, location, provider data version |
| `CalendarSystem` | The nine calendar systems |
| `CalendarVariant` | Regional / standard variant of a system |
| `DayBoundary` | When a calendar day begins: `engineDefault`, `civilMidnight`, `sunset`, `sunrise` |
| `RecurrencePolicy` | How yearless, leap-month, and invalid dates recur |
| `EngineProviderKind` | Provenance of a computation: `algorithmic`, `foundation`, `table`, `astronomy`, `dependency`, `hybrid` |
| `ValidationConfidence` | `canonical`, `providerVerified`, `unchecked` |
| `OccurrenceNote` | Structured note attached to an occurrence |
| `CalculationLocation` | Optional location for location-dependent calendars |
| `GregorianDayDateAdapter` | Bridge between `GregorianDay` and `Foundation.Date` |
| `CalendarEngineError` | Typed engine errors (unsupported system or variant, invalid date, invalid range, out of range, requires location, provider unavailable) |

### Engine modules

| Module | Types | Backend |
|--------|-------|---------|
| `ChronoCoreFoundation` | `HebrewEngine`, `HebrewMonth`, `HijriUmmAlQuraEngine` | Foundation ICU calendars |
| `ChronoCoreTables` | `NepaliBikramSambatEngine`, `BanglaEngine` | Embedded tables and rules |
| `ChronoCoreAstronomy` | `KoreanLunisolarEngine`, `VietnameseLunisolarEngine`, `IndianPanchangaEngine`, `Panchanga` | AstroCore (VSOP87D, ELP2000) |
| `ChronoCoreLunarCoreAdapter` | `ChineseLunarEngine` | LunarCore |

### ChronoCoreTesting

| Type | Description |
|------|-------------|
| `GoldenFixture` | Golden calendar test record loaded from JSON (source, query, expected days, provenance, parity metadata) |
| `GoldenFixtureSource` | Source spec inside a fixture (era, year/month/day, leap-month flag) |
| `FixtureRunner` | Evaluates a fixture against an engine and reports matches |
| `RangeCheck` | Large-range round-trip and monotonicity helpers |

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📋 Platform Support

| | Item | Range |
|-|------|-------|
| 🖥️ | Platforms | iOS 15+ · macOS 12+ · tvOS 15+ · watchOS 8+ · visionOS 1+ |
| 🔧 | Swift tools | 6.0+ |
| 📦 | Products | `ChronoCore` · `ChronoCoreFoundation` · `ChronoCoreTables` · `ChronoCoreAstronomy` · `ChronoCoreLunarCoreAdapter` · `ChronoCoreTesting` |

> \[!NOTE\]
>
> `ChronoCore`, `ChronoCoreFoundation`, and `ChronoCoreTables` are dependency-free (Foundation only). `ChronoCoreAstronomy` depends on AstroCore and `ChronoCoreLunarCoreAdapter` depends on LunarCore; add only the modules you use.

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📝 License

Copyright &copy; 2026-present [wbx1 Ltd.][profile-link].<br/>
This project is [MIT](./LICENSE) licensed.

<!-- LINK GROUP -->

[back-to-top]: https://img.shields.io/badge/-BACK_TO_TOP-151515?style=flat-square
[github-contributors-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/graphs/contributors
[github-contributors-shield]: https://img.shields.io/github/contributors/wbx1-Ltd/ChronoCore-Swift?color=c4f042&labelColor=black&style=flat-square
[github-forks-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/network/members
[github-forks-shield]: https://img.shields.io/github/forks/wbx1-Ltd/ChronoCore-Swift?color=8ae8ff&labelColor=black&style=flat-square
[github-issues-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/issues
[github-issues-shield]: https://img.shields.io/github/issues/wbx1-Ltd/ChronoCore-Swift?color=ff80eb&labelColor=black&style=flat-square
[github-license-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/blob/main/LICENSE
[github-license-shield]: https://img.shields.io/github/license/wbx1-Ltd/ChronoCore-Swift?color=white&labelColor=black&style=flat-square
[github-release-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/releases
[github-stars-link]: https://github.com/wbx1-Ltd/ChronoCore-Swift/stargazers
[github-stars-shield]: https://img.shields.io/github/stars/wbx1-Ltd/ChronoCore-Swift?color=ffcb47&labelColor=black&style=flat-square
[profile-link]: https://github.com/wbx1-Ltd
