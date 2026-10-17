# XPaddle — Android port

A Kotlin/Jetpack Compose conversion of the iOS/SwiftUI XPaddle project.
It ports all three modes 1:1:

- **1 player vs CPU** and **2 player (same device)** — `GameEngine.kt` +
  `GameScreen.kt`, ported from `GameEngine.swift` / `XPaddleContentView.swift`.
- **Play Nearby (2 devices)** — `DuelEngine.kt` + `DuelScreen.kt`, ported
  from `DuelEngine.swift` / `DuelView.swift`.

## Key mapping decisions

| iOS | Android |
|---|---|
| SwiftUI `Canvas` | Compose `Canvas` (`drawscope`) |
| `ObservableObject` / `@Published` | plain class + Compose `mutableStateOf` |
| `TimelineView(.animation)` game loop | `LaunchedEffect` looping `withFrameNanos` |
| `DragGesture` / raw `UIKit` multitouch | `Modifier.pointerInput` + `awaitEachGesture`, reading every active pointer per frame (mirrors the two-finger tracking `TouchTrackingUIView` did) |
| `MultipeerConnectivity` | Google Play Services **Nearby Connections** (`NetworkManager.kt`) — same auto-advertise + auto-discover + auto-accept design, same tiny `DuelMessage` protocol (now JSON over `Payload.fromBytes`) |
| `SafeAreaProvider` (UIKit insets) | Compose's `BoxWithConstraints` + measured size; `configureSafeArea` is still wired up for a notch/cutout hook if you want to feed real `WindowInsets.displayCutout` values in |
| `AudioServicesPlaySystemSound` + bundled `.wav` | `SoundPlayer.kt` using `SoundPool`, looking up `res/raw/<name>` by name the same way the iOS code looked up bundle files by name |
| `.statusBarHidden(true)` / `.persistentSystemOverlays(.hidden)` | `BarcodeMainActivity` hides system bars via `WindowInsetsControllerCompat`, swipeable back |
| `.fullScreenCover { DuelView() }` | full-screen `Dialog(usePlatformDefaultWidth = false) { DuelScreen() }` |

## What you need to add before building

1. **Gradle wrapper.** Open the project folder in Android Studio once and
   it will generate `gradle/wrapper/gradle-wrapper.jar` + `.properties`
   and `gradlew`/`gradlew.bat` for you (these binary/wrapper files aren't
   included here). Use Android Studio Koala+ / AGP 8.5+.
2. **Sound effects.** Drop `.wav`/`.ogg` files into `app/src/main/res/raw/`
   named `wall_hit`, `racquet_hit`, `golf_clap`, and `aw` (lowercase,
   no spaces — Android resource names require it). Without them the game
   runs silently and logs a one-time warning per missing name, exactly
   like the iOS `print("Missing sound file…")` fallback.
3. **App icon.** No launcher icon is included; add one via Android
   Studio's Image Asset tool, or the app will use the platform default.

## Nearby Connections vs MultipeerConnectivity — one real difference

Nearby Connections requires **runtime permissions** (Bluetooth + location
on Android <12, Bluetooth + Nearby Wi-Fi Devices on 12+), which iOS's
Bonjour-based Multipeer stack doesn't need in the same way. `DuelScreen`
requests these the moment you enter "Play Nearby"; if the user denies
them the screen falls back to `engine.stop()` and stays on the connecting
screen. You may want to add an explanatory rationale dialog before the
system prompt for a polished experience.

## Project layout

```
app/src/main/java/com/xpaddle/game/
  MainActivity.kt      — entry point, immersive fullscreen setup
  GameScreen.kt         — Compose UI: menu, 1P/2P court, overlays
  GameEngine.kt          — single-device physics/state (port of GameEngine.swift)
  DuelScreen.kt          — Compose UI: connecting screen, duel court
  DuelEngine.kt          — two-device duel physics/state + handshake (port of DuelEngine.swift)
  NetworkManager.kt      — Nearby Connections wrapper (port of NetworkManager.swift)
  SoundPlayer.kt         — SoundPool-based sound-by-name lookup
```
