# KaiToDo Style Guide

> Living document — update when design decisions change.
> Last updated: 2026-02-28

---

## Brand

| | |
|---|---|
| **App name** | Kai To Do |
| **Tagline** | Simple shared to-do lists for families |
| **Personality** | Friendly, playful, minimal — not corporate |

---

## Colors

All colors are defined as `Color` extensions in `KaiToDoApp.swift`.

| Token | Hex | Use |
|---|---|---|
| `kaiPurple` | `#7161EF` | Primary — buttons, FAB, active states, icon gradient start |
| `kaiBlue` | `#3D5A80` | Secondary — shared list accents |
| `kaiTeal` | `#4ECDC4` | Accent — onboarding page 3, task accents |
| `kaiMint` | `#95E1D3` | Light accent — subtle highlights |
| `kaiRed` | `#FF6B6B` | Destructive / warning — delete, reset actions |
| `kaiPink` | `#F38181` | Warm accent — buddy/sharing context |
| `kaiOrange` | `#FF8C42` | Energy / CTA — onboarding final page |
| `kaiYellow` | `#FFE66D` | Highlight / celebration — completion states |

### Gradients

| Use | Colors |
|---|---|
| Welcome screen & onboarding page 1 | `#7161EF` → `#4834D4` (top → bottom) |
| Onboarding page 2 (Create List) | `#FF8C42` → `#FF6B6B` |
| Onboarding page 3 (Add Tasks) | `#4ECDC4` → `#2196A6` |
| Onboarding page 4 (Add Buddy) | `#F38181` → `#C0392B` |
| Onboarding page 5 (All Set) | `#FFE66D` → `#FF8C42` |
| App icon | `#7161EF` → `#4834D4` |

---

## Typography

SwiftUI system fonts only — no custom typefaces.

| Role | Style |
|---|---|
| Navigation large title | `.navigationBarTitleDisplayMode(.large)` — default system bold |
| Section headers | `.headline` |
| Body / task text | `.body` |
| Captions / metadata | `.caption` / `.footnote` |
| FAB icon | `.system(size: 40)` |
| Add task `+` button | `.system(size: 40)` |
| Onboarding hero emoji | `90pt` via `.font(.system(size: 90))` |

---

## Spacing & Layout

| Element | Value |
|---|---|
| FAB diameter | `64pt` |
| FAB bottom padding | `24pt` from safe area |
| List row horizontal padding | SwiftUI List default |
| Corner radius (cards) | `12pt` |
| App icon corner radius | `220pt` (on 1024px canvas) |

---

## Iconography

SF Symbols only.

| Action | Symbol |
|---|---|
| Add task / new item | `plus.circle.fill` |
| Settings | `gear` |
| Delete / swipe-delete | `trash` (via `.swipeActions`) |
| Reset list | `arrow.counterclockwise` |
| Share list | `square.and.arrow.up` |
| Completed task | `checkmark.circle.fill` |
| Incomplete task | `circle` |
| Participants | `person.2` |
| More options | `ellipsis.circle` |

---

## Components

### FAB (Floating Action Button)
- `plus.circle.fill`, size `40pt`, color `kaiPurple`
- Positioned center-bottom of screen via `ZStack(alignment: .bottom)`
- 64pt hit area, 24pt bottom padding

### Task Row
- Native `List` row with `.swipeActions(edge: .trailing)` for delete
- Checkmark tap triggers spring scale animation + confetti
- Completed tasks show `checkmark.circle.fill` in list's accent color

### Navigation Bar
- Large title tappable by owner to inline-edit
- Tinted with list color: `.tint(Color(hex: list.color))` + `.toolbarBackground(...opacity: 0.10))`

### Onboarding
- Full-screen `TabView` with `PageTabViewStyle`
- 5 pages, each with: gradient bg, 90pt emoji hero, title, subtitle, bullet points
- Spring-animated hero on appear, staggered text/button fades
- Custom page dots at bottom

### Welcome / Nickname Screen
- Purple gradient background matching onboarding page 1
- Spring-animated emoji hero, frosted glass `TextField`
- CTA: "Let's Go! 🚀"

---

## Tone & Copy

- Use friendly emoji sparingly but consistently (✅ 🎉 🚀 🎊)
- Short, action-oriented button labels: "Let's Go!", "Done", "Reset List"
- Empty states should be encouraging, not clinical
  - ✅ "No tasks yet! Add one below 👇"
  - ❌ "No items found"
- Error/destructive actions use red (`kaiRed`) but remain polite in copy

---

## Dark Mode

- Supported via `@AppStorage("kaiColorScheme")` → `.preferredColorScheme()`
- Options: System (default), Light, Dark
- All colors use semantic SwiftUI colors where possible (`.primary`, `.secondary`)
- Gradient overlays use `.opacity()` rather than hard-coded dark values

---

## List Colors

Users pick a color per list. Available palette (hex values stored as strings on `TodoList.color`):

`#7161EF` `#FF6B6B` `#4ECDC4` `#FFE66D` `#FF8C42` `#95E1D3` `#F38181` `#3D5A80`
