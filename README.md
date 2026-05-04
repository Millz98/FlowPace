# FlowPace

**Interval timer for iPhone and iPad** — build routines from timed steps and repeating groups, run them full screen, and track how you use them.

This README describes **what the current codebase actually does**, in the same spirit as accurate App Store description text.

---

## What’s in the app today

These features are implemented and usable in this build:

- **Routines** — Create, edit, delete, duplicate, and reorder saved routines (stored on device).
- **Steps & groups** — Each routine mixes **steps** (single timed segments) and **groups** (nested steps with loop counts). Available to **all** users in the routine editor—not a Pro-only editor mode.
- **Timer** — Full-screen run with step-colored backgrounds, progress, pause/stop, and completion flow.
- **Audio** — Optional **system sounds** for step changes and completion (no bundled custom sound banks in the repo).
- **Haptics** — Step and completion feedback where the device supports it.
- **Appearance** — Background gradient theme from Settings.
- **Splash** — Short branded launch before the main UI.
- **Analytics** — Screen with time range, metrics, summary cards, **Charts** trend view (iOS 16+), and per-routine session breakdown, driven by locally saved completion history. **CSV export** is **Pro-only** (see below).
- **Settings** — Audio, appearance, haptics, Pro purchase / restore, legal links, app version, and (for Pro) iCloud sync status when configured.
- **Legal / info** — Privacy policy, terms of service, contact support entry points.

---

## FlowPace Pro (this build)

In code today, a Pro purchase (one-time or subscription, via StoreKit) unlocks:

1. **More routines** — Free users can save up to **3** routines; Pro removes that limit.
2. **iCloud sync** — When Pro and iCloud are available, routine changes can sync via **CloudKit** (private database, container `iCloud.com.flowpace.app`). Requires an Apple ID with iCloud and project signing set up for CloudKit.
3. **Analytics export** — **Export session data to CSV** from the Analytics screen. Charts and summaries remain visible without Pro; only the export action is gated.

**Not implemented in this repository** (no WidgetKit target or widget extension), even if similar wording appears elsewhere in marketing copy:

- **Home screen widgets** — Not shipped in this codebase.

**Editor “groups” vs. marketing “routine groups”** — The app’s **groups** are **loops of steps inside one routine**. There is **no** separate feature for grouping *multiple routines* into folders or tags; don’t describe that as shipped.

---

## Technical overview

- **UI** — SwiftUI; main navigation uses `NavigationView` with stack style on iPhone.
- **Persistence** — `UserDefaults` for routines and preferences; **CloudKit** optional for Pro sync as above.
- **Payments** — StoreKit 2; product IDs: `com.flowpace.pro.onetime`, `com.flowpace.pro.monthly`, `com.flowpace.pro.yearly`.
- **Entitlements** — See `FlowPace/FlowPace.entitlements` (CloudKit container, associated domains, Apple Pay merchant ID present for capability configuration).
- **Audio** — `AudioManager` uses `AudioServicesPlaySystemSound` only; no `SoundPacks/` or other custom audio bundles in the project.

Core timing and local data work **offline**. **iCloud sync** needs network and a valid iCloud account.

---

## Project layout

```
FlowPace/
├── FlowPace.xcodeproj/
├── FlowPace/
│   ├── FlowPaceApp.swift
│   ├── ContentView.swift
│   ├── Views/           # SwiftUI screens (list, editor, timer, settings, analytics, legal, …)
│   ├── Models/Models.swift
│   ├── Managers/        # Routine, timer, audio, haptics, StoreKit, CloudKit, background color
│   ├── Assets.xcassets/
│   ├── FlowPace.entitlements
│   └── Info.plist
└── README.md
```

---

## Run from source

1. Open **`FlowPace.xcodeproj`** in Xcode (iOS **17+** deployment target).
2. Select a **development team** and fix signing.
3. For CloudKit: enable **iCloud → CloudKit** and container **`iCloud.com.flowpace.app`** to match `FlowPace.entitlements` and `CloudKitManager`.
4. **⌘R** to build and run on simulator or device.

---

## Testing (quick)

- **Free tier** — Save a 4th routine (should be blocked); open Analytics without Pro (no CSV export).
- **Pro (StoreKit testing)** — Purchase / restore; unlimited saves; iCloud sync paths if CloudKit is configured.
- **Timer** — With audio on, hear system sounds on step change and completion.

---

## License & support

**License:** Proprietary — all rights reserved.  

**Support:** Add contact / web URLs here when you have them.

---

Built with SwiftUI and current iOS SDKs.
