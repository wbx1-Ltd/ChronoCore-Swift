<div align="center"><a name="readme-top"></a>

# ChronoCore

纯 Swift 实现的「仅日期」历法换算、循环与校验内核。<br/>
面向公历与传统历法系统设计：引擎可插拔、基准可验证、线程安全。

[English](./README.md) · [报告问题][github-issues-link] · [更新日志][github-release-link]

<!-- SHIELD GROUP -->

[![][github-stars-shield]][github-stars-link]
[![][github-forks-shield]][github-forks-link]
[![][github-issues-shield]][github-issues-link]
[![][github-license-shield]][github-license-link]<br/>
[![][github-contributors-shield]][github-contributors-link]

</div>

<details>
<summary><kbd>目录</kbd></summary>

#### TOC

- [✨ 特性](#-特性)
- [🧠 设计取向](#-设计取向)
- [📦 安装](#-安装)
- [🚀 使用](#-使用)
  - [📅 仅日期类型](#-仅日期类型)
  - [🔁 循环展开](#-循环展开)
  - [🪂 闰日策略](#-闰日策略)
  - [📆 日期区间](#-日期区间)
  - [🔄 反向构造](#-反向构造)
  - [🕐 Foundation.Date 互操作](#-foundationdate-互操作)
  - [🧪 黄金基准](#-黄金基准)
- [🧩 历法系统](#-历法系统)
- [🧪 测试](#-测试)
- [🗂️ API 概览](#️-api-概览)
- [📋 支持范围](#-支持范围)
- [📝 许可证](#-许可证)

####

<br/>

</details>

## ✨ 特性

> \[!IMPORTANT\]
>
> **Star Us** 即可第一时间收到 GitHub 的版本更新通知 \~ ⭐️

| | 功能 | 说明 |
|-|------|------|
| 📅 | **仅日期模型** | `GregorianDay` 值类型，构造即校验，遵循 `Comparable`、`Codable`，不含时刻歧义 |
| 🔁 | **循环展开** | 无年份的 spec 可展开为某一年或某个闭区间内的全部 occurrence |
| 🪂 | **闰日策略** | 2 月 29 日的回退方式：静默跳过，或就近调整到有效日并附带说明 |
| 🧭 | **日界模型** | 民用午夜、日落或日出；日界随请求传递，而非绑定在引擎上 |
| 🧱 | **引擎可插拔** | `CalendarEngine` 协议：可替换算法、Foundation、查表或天文等后端 |
| 🏷️ | **来源追踪** | 每个 occurrence 都记录其 provider、校验置信度与结构化说明 |
| 🌍 | **计算位置** | 为依赖地理位置的传统历法提供可选的经纬度与时区 |
| 🌐 | **九套历法系统** | 公历、中国农历、韩国、越南、希伯来、伊斯兰 Umm al-Qura、尼泊尔 Bikram Sambat、印度 Panchanga、孟加拉 |
| 🔭 | **高精度天文** | 阴阳历与 Panchanga 引擎通过 AstroCore 使用 VSOP87D 太阳与 ELP2000 月亮位置 |
| 🧪 | **黄金基准** | `ChronoCoreTesting` 加载 JSON 黄金数据，用于跨引擎、跨 provider 验证 |
| 🧵 | **线程安全** | 全面遵循 `Sendable` |
| 🧊 | **分层 target** | 内核保持纯净；Foundation、查表、天文与依赖等后端置于独立模块 |

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🧠 设计取向

ChronoCore 只解决一个问题：把一份历法日期描述（无论公历还是传统历法）转换为可信赖的公历日期，同时记录每一天是「如何」算出来的。

- **内核与应用代码刻意分离。** 调用方在 ChronoCore *之上* 自行构建 Contacts、CloudKit、小组件或分享格式的适配器，这些集成永远不是内核库的依赖。
- **日期是一份 spec，而非一串数字。** `CalendarDateSpec` 在月、日之外，还携带日界、循环策略、闰月标志与计算位置，使同一份请求在每个引擎中含义一致。
- **来源优先于猜测。** 每个 `CalendarOccurrence` 都记录由哪个 provider 计算（`EngineProviderKind`）、结果置信度如何（`ValidationConfidence`）以及做了哪些调整（`OccurrenceNote`），绝不静默修正。
- **算法才是来源。** 每套历法都有独立引擎，统一在一个协议之后，并以有出处的黄金基准验证。当平台历法（经 Foundation 的 ICU）权威时即采用并交叉校验；当其不权威或在最低平台不可用时，以天文或查表引擎作为 canonical provider，使同一输入在任意 OS 版本上结果一致。
- **用能力描述，而非开关。** 发布状态、支持范围、校验状态、是否需要位置、provider 数据版本，均由 `CalendarSystemCapability` 逐引擎描述，而不是由 `CalendarSystem` 枚举是否存在来暗示。

> \[!NOTE\]
>
> 九套目标历法系统均已实现并测试。其中两个引擎（印度 Panchanga 与尼泊尔 Bikram Sambat）在能力中标记为未验证，因为对照已出版权威历的逐行核对仍待完成；详见 [历法系统](#-历法系统)。

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📦 安装

### Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/wbx1-Ltd/ChronoCore-Swift.git", from: "0.1.0"),
]
```

然后在 target 中添加内核依赖：

```swift
.target(
    name: "YourTarget",
    dependencies: ["ChronoCore"]
),
```

`ChronoCoreTesting` 为你自己的测试 target 提供黄金基准辅助：

```swift
.testTarget(
    name: "YourTargetTests",
    dependencies: ["ChronoCore", "ChronoCoreTesting"]
),
```

或在 Xcode 中：**File → Add Package Dependencies…** → 粘贴上方 URL。

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🚀 使用

```swift
import ChronoCore

let engine = GregorianEngine()
```

### 📅 仅日期类型

`GregorianDay` 是一个经过校验、可排序的仅日期值。无效日期在构造时即失败，不存在静默进位。

```swift
let day = GregorianDay(year: 2026, month: 3, day: 14)!
print(day)                                  // "2026-03-14"
print(GregorianDay.isLeapYear(2024))        // true
print(GregorianDay.daysInMonth(2, year: 2024) ?? 0)  // 29

let invalid = GregorianDay(year: 2025, month: 2, day: 30)  // nil
```

### 🔁 循环展开

无年份的 spec（`year: nil`）每年循环。可将其展开为指定公历年内的全部 occurrence。

```swift
let spec = CalendarDateSpec(
    system: .gregorian,
    variant: .standard,
    year: nil,          // 无年份，每年循环
    month: 3,
    day: 14
)

let occurrences = try engine.occurrences(of: spec, inGregorianYear: 2026)
print(occurrences.first!.day)         // 2026-03-14
print(occurrences.first!.provider)    // .algorithmic
print(occurrences.first!.confidence)  // .canonical
```

### 🪂 闰日策略

2 月 29 日只存在于闰年。`recurrencePolicy` 决定非闰年时的行为。

```swift
let leapDay = CalendarDateSpec(
    system: .gregorian,
    variant: .standard,
    year: nil,
    month: 2,
    day: 29,
    recurrencePolicy: .nearestValidDay
)

// 2025 没有 2 月 29 日，于是调整到 2 月 28 日并记录原因
let resolved = try engine.occurrences(of: leapDay, inGregorianYear: 2025)
print(resolved.first!.day)    // 2025-02-28
print(resolved.first!.notes)  // [.adjustedToNearestValidDay]

// 引擎默认会直接跳过不可能的闰日
let skipping = CalendarDateSpec(
    system: .gregorian, variant: .standard, year: nil, month: 2, day: 29
)
print(try engine.occurrences(of: skipping, inGregorianYear: 2025))  // []
```

### 📆 日期区间

在一个闭区间内展开循环 spec：

```swift
let range = GregorianDay(year: 2024, month: 1, day: 1)!
        ... GregorianDay(year: 2026, month: 12, day: 31)!

let across = try engine.occurrences(of: spec, in: range)
print(across.map(\.day))  // [2024-03-14, 2025-03-14, 2026-03-14]
```

### 🔄 反向构造

从一个具体日期重建 spec：

```swift
let rebuilt = try engine.dateSpec(from: GregorianDay(year: 2026, month: 3, day: 14)!)
print(rebuilt.system, rebuilt.month, rebuilt.day)  // gregorian 3 14
```

### 🕐 Foundation.Date 互操作

把 `GregorianDay` 桥接为任意时区当天零点的 `Foundation.Date`：

```swift
import Foundation

let adapter = GregorianDayDateAdapter(
    timeZone: TimeZone(identifier: "Asia/Shanghai")!
)
let date = adapter.date(for: GregorianDay(year: 2026, month: 3, day: 14)!)
// 上海时间 2026-03-14 00:00:00
```

### 🧪 黄金基准

`ChronoCoreTesting` 解码 JSON 黄金数据，让引擎结果可对照已知正确的日期：

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

## 🧩 历法系统

每套目标历法都有引擎，并以有出处的黄金基准验证。`Provider` 列为 canonical 计算方式；`已验证` 反映各引擎的 `CalendarSystemCapability`。

| | 系统 | 引擎（模块） | Provider | 已验证 | 范围 |
|-|------|--------------|----------|--------|------|
| ✅ | **公历 Gregorian** | `GregorianEngine`（ChronoCore） | algorithmic | 是 | 1600 至 2400 |
| ✅ | **中国农历** | `ChineseLunarEngine`（LunarCoreAdapter） | dependency（LunarCore） | 是 | 1900 至 2100 |
| ✅ | **韩国阴阳历** | `KoreanLunisolarEngine`（Astronomy） | astronomy，UTC+9 | 是 | 1900 至 2099 |
| ✅ | **越南阴阳历** | `VietnameseLunisolarEngine`（Astronomy） | astronomy，UTC+7 | 是 | 1968 至 2099 |
| ✅ | **希伯来历** | `HebrewEngine`（Foundation） | foundation（ICU） | 是 | 1900 至 2200 |
| ✅ | **伊斯兰历 Umm al-Qura** | `HijriUmmAlQuraEngine`（Foundation） | foundation（ICU） | 是 | 1900 至 2100 |
| ✅ | **尼泊尔 Bikram Sambat** | `NepaliBikramSambatEngine`（Tables） | table | 待核 | BS 2000 至 2110 |
| ✅ | **印度 Panchanga** | `IndianPanchangaEngine`（Astronomy） | astronomy，Lahiri | 待核 | 1900 至 2099 |
| ✅ | **孟加拉历** | `BanglaEngine`（Tables） | table（revised） | 是 | 约 1919 至 2119 |

每个系统通过 `CalendarVariant` 暴露其标准或地区变体（如 `chineseMainland`、`koreanModern`、`vietnameseModernUTC7`、`ummAlQuraSaudi`、`bangladeshRevised`）。韩国与越南采用天文计算（不以中国农历近似），并对照 Foundation `.dangi` 与 `.vietnamese` 交叉校验；已记录的边界分歧写入测试。印度 Panchanga 返回某地点日出时刻的完整五支（tithi、nakshatra、yoga、karana、masa）。

> \[!NOTE\]
>
> 「待核」表示引擎已实现且经天文或锚点验证，但与已出版官方历的逐行对照仍未完成。该状态通过 `CalendarSystemCapability.isValidated` 如实暴露。

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🧪 测试

| 指标 | 数值 |
|------|------|
| 测试函数 | **102** |
| 测试套件 | **15** |
| 黄金基准 | **45** |

运行测试：

```bash
swift test
```

覆盖：

- ✅ **逐引擎单元测试**：九套系统的校验、循环、闰月与日界处理
- ✅ **有出处的黄金基准**：九套历法共 45 条记录（节日、新年、闰月、改历边界、多结果年份）
- ✅ **Provider parity**：天文引擎逐日对照 Foundation `.dangi`、`.vietnamese`；Foundation 引擎对照 ICU；中国农历对照 Foundation `.chinese`
- ✅ **反向与区间**：查表引擎的大范围公历 round-trip、多年 occurrence 区间、单调性
- ✅ **循环结果数**：0、1、多个 occurrence（例如同一公历年内出现两次的伊斯兰历日期）
- ✅ **序列化**：每个 public `Codable` 模型可往返，每个 fixture 文件按 schema 解码
- ✅ **注册表**：每个 `CalendarSystem` 都解析到引擎，具备完整能力与唯一指纹

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 🗂️ API 概览

### ChronoCore

| 类型 | 说明 |
|------|------|
| `GregorianDay` | 仅日期的公历值（年/月/日），经校验，遵循 `Comparable`、`Codable`，并提供儒略日数算术 |
| `CalendarDateSpec` | 一次日期 / 循环请求的完整描述（系统、变体、纪元、年、月、日、闰月标志、日界、策略、位置） |
| `CalendarEngine` | 所有历法引擎遵循的协议 |
| `GregorianEngine` | 外推公历实现 |
| `CalendarEngineRegistry` | 按系统查找引擎，并汇总各引擎能力 |
| `CalendarOccurrence` | 一个已解析日期及其来源（provider、置信度、说明） |
| `CalendarSystemCapability` | 逐引擎的状态、范围、校验、是否需位置、provider 数据版本、扩展提示 |
| `CalendarComputationFingerprint` | 覆盖引擎版本、系统、变体、spec、日界、位置、provider 数据版本的稳定缓存键 |
| `CalendarSystem` | 九套历法系统 |
| `CalendarVariant` | 系统的地区 / 标准变体 |
| `DayBoundary` | 一个历法日的起点：`engineDefault`、`civilMidnight`、`sunset`、`sunrise` |
| `RecurrencePolicy` | 无年份、闰月与无效日期的循环方式 |
| `EngineProviderKind` | 计算来源：`algorithmic`、`foundation`、`table`、`astronomy`、`dependency`、`hybrid` |
| `ValidationConfidence` | `canonical`、`providerVerified`、`unchecked` |
| `OccurrenceNote` | 附加在 occurrence 上的结构化说明 |
| `CalculationLocation` | 依赖位置的历法所需的可选位置信息 |
| `GregorianDayDateAdapter` | `GregorianDay` 与 `Foundation.Date` 之间的桥接 |
| `CalendarEngineError` | 类型化引擎错误（不支持的系统或变体、无效日期、无效区间、超出范围、需要位置、provider 不可用） |

### 引擎模块

| 模块 | 类型 | 后端 |
|------|------|------|
| `ChronoCoreFoundation` | `HebrewEngine`、`HebrewMonth`、`HijriUmmAlQuraEngine` | Foundation ICU 历法 |
| `ChronoCoreTables` | `NepaliBikramSambatEngine`、`BanglaEngine` | 内嵌表与规则 |
| `ChronoCoreAstronomy` | `KoreanLunisolarEngine`、`VietnameseLunisolarEngine`、`IndianPanchangaEngine`、`Panchanga` | AstroCore（VSOP87D、ELP2000） |
| `ChronoCoreLunarCoreAdapter` | `ChineseLunarEngine` | LunarCore |

### ChronoCoreTesting

| 类型 | 说明 |
|------|------|
| `GoldenFixture` | 从 JSON 加载的黄金历法测试记录（源、查询、期望日期、出处、parity 元数据） |
| `GoldenFixtureSource` | fixture 内的源 spec（纪元、年/月/日、闰月标志） |
| `FixtureRunner` | 将 fixture 对引擎求值并报告匹配结果 |
| `RangeCheck` | 大范围 round-trip 与单调性辅助 |

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📋 支持范围

| | 项目 | 范围 |
|-|------|------|
| 🖥️ | 平台 | iOS 15+ · macOS 12+ · tvOS 15+ · watchOS 8+ · visionOS 1+ |
| 🔧 | Swift tools | 6.0+ |
| 📦 | 产物 | `ChronoCore` · `ChronoCoreFoundation` · `ChronoCoreTables` · `ChronoCoreAstronomy` · `ChronoCoreLunarCoreAdapter` · `ChronoCoreTesting` |

> \[!NOTE\]
>
> `ChronoCore`、`ChronoCoreFoundation`、`ChronoCoreTables` 无第三方依赖（仅 Foundation）。`ChronoCoreAstronomy` 依赖 AstroCore，`ChronoCoreLunarCoreAdapter` 依赖 LunarCore；按需引入对应模块即可。

<div align="right">

[![][back-to-top]](#readme-top)

</div>

## 📝 许可证

Copyright &copy; 2026-present [wbx1 Ltd.][profile-link].<br/>
本项目基于 [MIT](./LICENSE) 许可证发布。

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
