# FlowPace iOS App

**A flexible, polished interval timer for iPhone and iPad**

FlowPace lets users build timed sequences from steps and repeating groups, with a SwiftUI interface tuned for focus sessions and workouts.

## Features

### Core (all users)

- **Routines** — Create, save, edit, delete, reorder, and duplicate timer routines
- **Steps & groups** — Named steps with duration and color; groups with loop counts
- **Active timer** — Large display, step-colored backgrounds, progress feedback
- **Audio** — System sounds for step changes and completion; toggle and volume preference in **Settings → Audio**
- **Haptics** — Taptic feedback where supported
- **Appearance** — Customizable background gradient themes
- **Splash** — Branded launch experience before the main UI

### Pro (StoreKit — in-app purchase)

- **Unlimited routines** — Free tier is limited to **3** saved routines; Pro removes the cap
- **iCloud sync** — CloudKit-backed sync of routines for signed-in iCloud users (Pro)
- **Advanced analytics** — Deeper stats and trends (Pro-gated in app)
- **Routine groups** — Organization feature called out for Pro in product copy
- **Home screen widgets** — Listed among Pro capabilities for marketing / future delivery

### Technical

- **SwiftUI** — Declarative UI; `NavigationView` with stack style on iPhone
- **Persistence** — `UserDefaults` for routines and preferences; optional **CloudKit** private database when Pro + iCloud available
- **StoreKit 2** — Products, purchases, transaction listener on the main actor
- **CloudKit** — Container `iCloud.com.flowpace.app` (must match Apple Developer + Xcode capability)
- **Audio** — No `SoundPacks/` (or other) custom audio bundles in the project; `AudioManager` triggers system sounds only.

Core timer and local data work **without a network**; **iCloud sync** requires network and an eligible Apple ID.

## Project structure

```
FlowPace/
├── FlowPace.xcodeproj/
├── FlowPace/
│   ├── FlowPaceApp.swift
│   ├── ContentView.swift
│   ├── Views/
│   │   ├── RoutineListView.swift
│   │   ├── RoutineEditorView.swift
│   │   ├── ActiveTimerView.swift
│   │   ├── SettingsView.swift
│   │   ├── AnalyticsView.swift
│   │   ├── SplashScreenView.swift
│   │   ├── AddStepView.swift / AddGroupView.swift / EditItemView.swift
│   │   ├── PrivacyPolicyView.swift / TermsOfServiceView.swift / ContactSupportView.swift
│   │   └── …
│   ├── Models/
│   │   └── Models.swift
│   ├── Managers/
│   │   ├── RoutineManager.swift
│   │   ├── TimerManager.swift
│   │   ├── AudioManager.swift
│   │   ├── HapticManager.swift
│   │   ├── StoreKitManager.swift
│   │   ├── CloudKitManager.swift
│   │   └── BackgroundColorManager.swift
│   ├── Assets.xcassets/
│   ├── FlowPace.entitlements
│   └── Info.plist
└── README.md
```

## Getting started

### Prerequisites

- **Xcode** 15+ recommended (project targets **iOS 17+**)
- **macOS** with Xcode installed
- Simulator or a physical device

### Run the app

1. Clone the repo and open **`FlowPace.xcodeproj`**
2. **Signing & Capabilities** — Select your team; ensure **iCloud → CloudKit** is enabled and the container **`iCloud.com.flowpace.app`** matches `FlowPace.entitlements` and `CloudKitManager`’s container identifier
3. Build and run (**⌘R**)

### First run

- Starts on the splash, then the routine list (empty until you add routines)
- Create routines from the list / editor; configure audio under **Settings**

## Architecture (high level)

- **Models** — `Routine`, `Step`, `Group`, `RoutineItem`, colors, completed-session types
- **Managers** — `@MainActor` observable objects for timer flow, persistence, audio, StoreKit, CloudKit, and UI chrome (backgrounds)
- **Views** — Consume managers via `@EnvironmentObject` / bindings; sheets for editor, settings, analytics

## Configuration

### Entitlements (`FlowPace/FlowPace.entitlements`)

- **iCloud** — CloudKit + container `iCloud.com.flowpace.app`
- **Associated domains** — `applinks:flowpace.app`
- **Apple Pay** — Merchant `merchant.com.flowpace.app` (if using Apple Pay in the app)

### StoreKit product identifiers

Configure the same IDs in **App Store Connect** (and StoreKit Configuration files for local testing):

- `com.flowpace.pro.onetime`
- `com.flowpace.pro.monthly`
- `com.flowpace.pro.yearly`

## Testing

- Exercise **free tier** — routine limit (3), analytics / Pro gates where still applied
- Exercise **Pro** — StoreKit testing configuration, purchases, restore, iCloud sync paths
- **Audio** — With **audio enabled**, confirm step-change and completion **system** sounds during a timer run (no custom asset playback)

## Deployment checklist

1. Version / build in Xcode and App Store Connect  
2. App ID capabilities: **iCloud (CloudKit)**, **In-App Purchase**, and any others you ship (associated domains, Apple Pay, etc.)  
3. CloudKit Dashboard for **`iCloud.com.flowpace.app`**  
4. Device testing (audio, haptics, purchases, sync)

## Contributing

- Prefer small, focused changes; keep SwiftUI previews and `README` in sync when behavior or capabilities change  
- Follow existing naming and file layout under `FlowPace/`

## License

Proprietary — all rights reserved.

## Support

Contact and web links can be added here when they are finalized.

---

Built with SwiftUI and current iOS APIs.
