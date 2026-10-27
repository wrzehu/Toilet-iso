# 🚽 Toilet Timer — iOS App Specification

> **Platform:** iOS (Native — Swift + SwiftUI)
> **Repo:** `Toilet-iso`
> **Minimum iOS Version:** iOS 16.0+
> **Language:** Swift 5.9+
> **UI Framework:** SwiftUI
> **Backend:** Firebase (Firestore + Authentication)
> **Ads:** Google AdMob (Banner + Interstitial)
> **Localization:** `.strings` / `.xcstrings` resource system (multi-language ready)

---

## 📖 App Overview

**Toilet Timer** is a fun, social countdown app designed to hurry up people sitting too long on the toilet.

The app operates in two roles:
- **SITTER** — the person on the toilet who controls the timer
- **WAITER** — the person(s) waiting outside who receives the alarm

Devices are paired via QR code scanning and communicate in real-time through Firebase Firestore.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Architecture | MVVM |
| Backend / Realtime DB | Firebase Firestore |
| Auth | Firebase Anonymous Auth |
| Storage | Firebase Storage |
| Notifications | Firebase Cloud Messaging (APNs) |
| Ads | Google AdMob (via `GoogleMobileAds` SDK) |
| QR Generation | `CoreImage` (`CIQRCodeGenerator`) |
| QR Scanning | `AVFoundation` or `VisionKit` (`DataScannerViewController`) |
| Animations | SwiftUI `withAnimation` + `Canvas` + `TimelineView` |
| Localization | `Localizable.strings` / `.xcstrings` |
| DI | Manual / `@EnvironmentObject` |
| Navigation | SwiftUI `NavigationStack` |

---

## 📁 Project Structure

```
ToiletTimer/
├── ToiletTimerApp.swift               # @main entry point
├── AppDelegate.swift                  # Firebase + AdMob setup
├── Info.plist                         # Permissions, AdMob App ID
├── Resources/
│   ├── en.lproj/Localizable.strings   # English strings
│   ├── pl.lproj/Localizable.strings   # Polish strings
│   ├── de.lproj/Localizable.strings   # German strings
│   ├── Assets.xcassets/               # Images, colors
│   │   ├── ic_sitter.imageset/
│   │   ├── ic_waiter.imageset/
│   │   ├── anim_man_normal.imageset/
│   │   └── anim_man_skeleton.imageset/
│   └── alarm_sound.mp3                # To be provided by client
├── Data/
│   ├── Model/                         # Swift structs: Session, Device, TimerState
│   └── Repository/                    # FirestoreSessionRepository
├── Domain/
│   └── UseCase/                       # Business logic use cases
├── UI/
│   ├── Theme/                         # Color, Font, AppTheme
│   ├── Screen/
│   │   ├── Splash/                    # SplashView
│   │   ├── RoleSelect/                # RoleSelectView
│   │   ├── Sitter/                    # SitterView + SitterViewModel
│   │   ├── Waiter/                    # WaiterView + WaiterViewModel
│   │   ├── Pair/                      # PairView (QR generate + scan)
│   │   └── Settings/                  # SettingsView + SettingsViewModel
│   ├── Component/                     # Shared SwiftUI Views
│   └── Animation/                     # SandglassAnimationView, SkeletonFadeView
└── Util/                              # Extensions, helpers
```

---

## 🖥️ Screens

### 1. Splash Screen (`SplashView`)

- Display app logo for 1.5 seconds
- Check saved role in `UserDefaults`
- Navigate to **Role Selection** or directly to appropriate main screen

---

### 2. Role Selection Screen (`RoleSelectView`)

**Layout:**
- Screen divided **50/50 horizontally** (using `HStack` with equal `frame`)
- **Left tile — SITTER:**
  - Background: asset `ic_sitter` (placeholder image)
  - Title: `NSLocalizedString("role_sitter")` → "SITTER"
  - Subtitle: `NSLocalizedString("role_sitter_desc")` → "I'm on the throne"
- **Right tile — WAITER:**
  - Background: asset `ic_waiter` (placeholder image)
  - Title: `NSLocalizedString("role_waiter")` → "WAITER"
  - Subtitle: `NSLocalizedString("role_waiter_desc")` → "I'm waiting outside"
- Each tile: rounded rectangle card with scale press animation (`.scaleEffect` on tap)

**Behavior:**
- Tap SITTER → navigate to **SITTER Main Screen**
- Tap WAITER → navigate to **WAITER Main Screen**
- Selected role saved to `UserDefaults`

---

### 3. SITTER Main Screen (`SitterView`)

**Layout:**
- `NavigationStack` with toolbar:
  - Title: app name (centered)
  - Trailing toolbar item: ⚙️ button → push **Settings Screen**
- Center: **Main Animation** (see Animation section)
- Timer preset selector (4 large styled buttons in a grid):
  - `5 min` / `10 min` / `15 min` / `30 min`
  - Keys: `timer_5min`, `timer_10min`, `timer_15min`, `timer_30min`
- **START** button (`btn_start`)
- Bottom: **AdMob Banner Ad View** (visible when timer is NOT running)

**Behavior:**
- SITTER selects duration → taps START
- Firestore document updated: `{ status: "running", duration: X, startedAt: Timestamp }`
- Countdown displayed on screen
- Banner ad hidden while timer is running
- **STOP** button replaces START while running (`btn_stop`)
- When countdown reaches 0:
  - Play `alarm_sound.mp3` via `AVAudioPlayer`
  - Firestore updated: `{ status: "finished" }`
  - Display completion state

**Paired WAITERs section:**
- Scrollable list of connected WAITER devices below the timer presets
- Show each WAITER's name/device ID + online status indicator

---

### 4. WAITER Main Screen (`WaiterView`)

**Layout:**
- `NavigationStack` with toolbar:
  - Title: app name (centered)
  - Trailing: ⚙️ button → **Settings Screen**
- Center: **Main Animation** (read-only, same visual as SITTER)
- Large countdown display (synced from Firebase)
- Status label using localized strings: `waiter_waiting`, `waiter_countdown`, `waiter_time_up`
- Bottom: **AdMob Banner Ad** (always visible)

**Behavior:**
- Real-time Firestore listener on paired SITTER's session document
- `status == "running"` → show live countdown calculated from `startedAt + duration - now`
- `status == "finished"`:
  - Play `alarm_sound.mp3`
  - Present **AdMob Interstitial** fullscreen ad
  - After dismissal: show completion message (`waiter_time_up`)
- `status == "stopped"`:
  - Present **AdMob Interstitial** fullscreen ad immediately
  - After dismissal: return to idle state (`waiter_waiting`)

> [!IMPORTANT]
> The interstitial ad must appear on WAITER's device on **both** timer completion AND SITTER-triggered stop.

---

### 5. QR Pairing Screen (`PairView`)

**Two modes:**

#### SITTER — Generate QR
- Use `CIQRCodeGenerator` to produce a QR code from JSON:
  `{ "sitterId": "<uid>", "sessionToken": "<token>" }`
- Display `Image` from generated `CIImage` scaled to 250×250pt
- Instruction: `pair_show_qr`
- List of currently paired WAITERs below the QR code

#### WAITER — Scan QR
- Use `DataScannerViewController` (iOS 16+) or `AVCaptureSession`
- On successful decode: register WAITER in Firestore under parsed `sitterId`
- Success → navigate to **WAITER Main Screen** with pairing confirmed
- Instruction: `pair_scan_qr`

**Navigation:** Accessible from Settings for both roles

---

### 6. Settings Screen (`SettingsView`)

**Layout:**
- `NavigationStack` form / `List` layout
- Title: `settings_title`
- Sections:

**SITTER Settings:**
- **Section: Paired WAITERs** (`settings_paired_waiters`)
  - `ForEach` list of paired WAITER devices
  - Swipe-to-delete or trailing remove button per row
  - Button: `settings_add_waiter` → open QR generate mode
- **Section: Animation Style** (`settings_animation`)
  - `Picker` (segmented or list):
    - `anim_sand` — Sandglass Man
    - `anim_skeleton` — Fade to Skeleton
- **Section: Language** (`settings_language`)
  - `Picker` for override language: `lang_en`, `lang_pl`, `lang_de`

**WAITER Settings:**
- **Section: My SITTERs** (`settings_my_sitters`)
  - List of paired SITTERs
  - Swipe-to-delete / disconnect per row
  - Button: `settings_share_qr` → open QR scan mode

> [!NOTE]
> A SITTER can have **multiple WAITERs**. A WAITER can be paired to **multiple SITTERs**.

---

## 🎬 Animations

User selects preferred style in Settings. Both are SwiftUI-native.

### Option A: "Sandglass Man" 🏖️
- `ZStack` composition:
  - Background: `Image("anim_sandglass_bg")` — man on toilet illustration
  - Transparent toilet bowl region: `Canvas` view overlaid
  - Sand particle system inside `TimelineView(.animation)`:
    - Array of `SandParticle` structs `{ x: CGFloat, y: CGFloat, size: CGFloat, speed: CGFloat }`
    - Each frame: update `y` by `speed * dt`; reset to top when past bowl bottom
    - Draw using `context.fill(circle, with: .color(.yellow.opacity(0.8)))`
- Idle: normal speed; timer running: speed multiplied by 2.0
- Animation loops indefinitely

### Option B: "Skeleton Fade" 💀
- `ZStack`:
  - `Image("anim_man_normal")` with `.opacity(normalOpacity)`
  - `Image("anim_man_skeleton")` with `.opacity(1.0 - normalOpacity)`
- `withAnimation(.easeInOut(duration: fadeDuration).repeatForever(autoreverses: true))` cycles `normalOpacity` between 1.0 and 0.0
- Default `fadeDuration`: 4.0 seconds
- When timer running: duration shortened based on remaining time (approaches 1.0s at 0)

> [!NOTE]
> Assets: `anim_man_normal` and `anim_man_skeleton` in `Assets.xcassets` — to be provided by client.

---

## 🔔 Sound

- File: `alarm_sound.mp3` in app bundle — **to be provided by client**
- Playback using `AVAudioPlayer`
- Triggered on both SITTER and WAITER when timer finishes
- Respects device silent mode (use `AVAudioSession.Category.playback` if desired to override, or `.ambient` to respect silent switch — TBD with client)

---

## 📢 Advertising (AdMob)

| Placement | Type | Trigger |
|---|---|---|
| SITTER timer setup (bottom) | Banner (`GADBannerView`) | Visible when timer not running |
| WAITER waiting screen (bottom) | Banner (`GADBannerView`) | Always visible |
| WAITER — timer finished | Interstitial (`GADInterstitialAd`) | `status == "finished"` |
| WAITER — timer interrupted | Interstitial (`GADInterstitialAd`) | `status == "stopped"` |

- AdMob App ID set in `Info.plist` under key `GADApplicationIdentifier`
- Ad Unit IDs stored in `Localizable.strings` or a `Config.plist`
- Use **test Ad Unit IDs** during development

---

## 🌐 Localization

All visible strings via `NSLocalizedString` / `String(localized:)`. No hardcoded strings.

**`Localizable.strings` keys (base English):**

```
/* Roles */
"role_sitter" = "SITTER";
"role_sitter_desc" = "I'm on the throne";
"role_waiter" = "WAITER";
"role_waiter_desc" = "I'm waiting outside";

/* Timer */
"timer_5min" = "5 min";
"timer_10min" = "10 min";
"timer_15min" = "15 min";
"timer_30min" = "30 min";
"btn_start" = "START";
"btn_stop" = "STOP";

/* Waiter states */
"waiter_waiting" = "Waiting for the signal…";
"waiter_countdown" = "Time remaining: %@";
"waiter_time_up" = "TIME'S UP! 🚽";
"waiter_stopped" = "Timer was stopped.";

/* Pairing */
"pair_show_qr" = "Show this QR code to your WAITER";
"pair_scan_qr" = "Scan the SITTER's QR code";
"pair_success" = "Successfully paired!";
"pair_error" = "Pairing failed. Please try again.";

/* Settings */
"settings_title" = "Settings";
"settings_paired_waiters" = "Paired WAITERs";
"settings_add_waiter" = "Add WAITER (show QR)";
"settings_my_sitters" = "My SITTERs";
"settings_share_qr" = "Connect to SITTER (scan QR)";
"settings_animation" = "Animation Style";
"settings_language" = "Language";
"anim_sand" = "Sandglass Man";
"anim_skeleton" = "Fade to Skeleton";
"lang_en" = "English";
"lang_pl" = "Polish";
"lang_de" = "German";
```

---

## 🔒 Firebase Data Model

Same shared Firestore schema as Android:

### Collection: `sessions`

```
sessions/{sitterId}/
  ├── sitterId: String
  ├── createdAt: Timestamp
  ├── status: "idle" | "running" | "finished" | "stopped"
  ├── duration: Number (seconds)
  ├── startedAt: Timestamp | null
  └── waiters: [{ waiterId: String, deviceName: String, joinedAt: Timestamp }]
```

---

## 🧩 Key Dependencies (Package.swift / SPM)

```swift
// Firebase
.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
// → FirebaseFirestore, FirebaseAuth, FirebaseMessaging

// Google Mobile Ads (AdMob)
// Add via CocoaPods: pod 'Google-Mobile-Ads-SDK'
// OR via SPM: https://github.com/googleads/swift-package-manager-google-mobile-ads

// QR Scanning: built-in VisionKit / AVFoundation (no extra package needed)
// QR Generation: built-in CoreImage (no extra package needed)
```

---

## 🔐 Info.plist Keys Required

```xml
<!-- Camera for QR scanning -->
<key>NSCameraUsageDescription</key>
<string>Used to scan QR codes for device pairing</string>

<!-- AdMob App ID -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>

<!-- Background audio -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

---

## 🗂️ Assets to be Provided by Client

| Asset Name | Purpose |
|---|---|
| `ic_sitter` (in Assets.xcassets) | SITTER tile background — Role Selection screen |
| `ic_waiter` (in Assets.xcassets) | WAITER tile background — Role Selection screen |
| `anim_man_normal` (in Assets.xcassets) | Normal man on toilet — Skeleton Fade animation |
| `anim_man_skeleton` (in Assets.xcassets) | Skeleton on toilet — Skeleton Fade animation |
| `anim_sandglass_bg` (in Assets.xcassets) | Background for Sandglass Man animation |
| `alarm_sound.mp3` (in bundle) | Alarm sound played when timer ends |

---

## ✅ Development Checklist

- [ ] Xcode project setup with correct bundle ID and signing
- [ ] Firebase project setup (iOS app registered, `GoogleService-Info.plist` added)
- [ ] AdMob account + App ID + Ad Unit IDs configured in `Info.plist` and code
- [ ] Anonymous Firebase Auth flow
- [ ] Role selection + persistence (`UserDefaults`)
- [ ] `NavigationStack` routing for all screens
- [ ] Firestore session document CRUD (SitterViewModel)
- [ ] QR code generation with `CIQRCodeGenerator` (SITTER)
- [ ] QR code scanning with `DataScannerViewController` / `AVFoundation` (WAITER)
- [ ] Real-time Firestore `addSnapshotListener` on WAITER screen
- [ ] Timer countdown logic (SITTER side, `Timer.publish`)
- [ ] Timer sync to Firestore on START / STOP / FINISH
- [ ] WAITER receives real-time timer state and shows countdown
- [ ] Alarm sound playback on both devices (`AVAudioPlayer`)
- [ ] AdMob Banner integration (`UIViewRepresentable` wrapper for `GADBannerView`)
- [ ] AdMob Interstitial integration (WAITER — on finish + on stop)
- [ ] Animation Option A: Sandglass Man (`TimelineView` + `Canvas` particle system)
- [ ] Animation Option B: Skeleton Fade (`withAnimation` crossfade between two images)
- [ ] Settings screen: manage WAITERs (add / remove)
- [ ] Settings screen: animation style toggle
- [ ] Settings screen: language selector (in-app locale override)
- [ ] Full localization: EN, PL, DE `Localizable.strings`
- [ ] Push notifications via APNs / FCM (timer alerts when app is backgrounded)
- [ ] Multi-WAITER support (SITTER can have N WAITERs)
- [ ] Multi-SITTER support (WAITER can be paired to N SITTERs)
- [ ] App Store review: privacy manifest, required reason APIs
