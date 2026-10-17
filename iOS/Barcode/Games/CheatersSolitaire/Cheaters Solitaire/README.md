# Cheaters Solitaire — Skeleton

A SwiftUI Klondike solitaire skeleton for macOS + iOS, structured around a
hidden cheat system with tunable, probabilistic "consequences."

## What's here

```
CheatersSolitaire/
  CheatersSolitaireApp.swift      App entry point (shared iOS/macOS target)
  Models/
    Card.swift                    Suit, Rank, Card, stacking rules
    Deck.swift                    Shuffle/draw
    DealerAppearance.swift        Randomized handedness + gender (not cheats)
    SolitaireGameState.swift               Core game engine + hidden cheat methods
  Cheats/
    CheatSettings.swift           Developer-tunable probabilities/volumes
    CheatEngine.swift             Cheat-point tracking + consequence rolls
  Audio/
    SoundManager.swift            Shuffle/croak/ribbit/snap playback
  Views/
    SolitaireContentView.swift             Root layout, wires everything together
    CardView.swift                Single card rendering
    DeckView.swift                Stock pile + single/double/triple tap logic
    MultiTapView.swift            Reliable native tap-count detection (UIKit/AppKit)
    DealerHandOverlayView.swift   Hands-only overlay, no dealer figure
    TableauColumnView.swift       Columns + face-down peek/grab cheat
    WasteView.swift               3-card fan where ANY card is playable (cheat)
    FoundationsView.swift         4 suit piles
    CritterOverlayView.swift      Bug-crawl -> frog-snap consequence animation
```

## How to turn this into an actual Xcode project

1. In Xcode: **File > New > Project > Multiplatform > App**, name it
   `CheatersSolitaire`, and make sure "SwiftUI" is selected (this gives you
   one shared target that builds for both iOS and macOS — matches how this
   skeleton is written).
2. Delete the generated placeholder `SolitaireContentView.swift` / App file, then drag
   the folders above into the project navigator (check "Copy items if needed").
3. Add the asset catalog entries listed below.
4. Add the audio files listed below (or comment out the `SoundManager` calls
   temporarily — everything else will still compile and run without them).
5. Build and run. `SolitaireContentView` calls `game.startNewGame()` on appear, which
   puts the deck on the table (`.deckOnTable` phase) — tap it to begin.

## Assets.xcassets you need to create

**Colors:** none needed — pip colors (red/black) are fixed directly in
`CardView.swift` (`cardRed`/`cardBlack`), not pulled from the asset catalog,
so there's no color set to configure here.

**Images**:
- `TableFelt` — the table background (an image, not a color — drawn with
  `Image("TableFelt")`, so it won't auto-adapt to dark mode on its own; add a
  second dark-mode image and a colorScheme check if you want that later).
- `CardFront` — one blank card face (corners pre-rounded in the art). Rank and
  suit are drawn on top of this in code, so this single image covers all 52
  cards — no need for 52 separate front images.
- `CardBack` — the face-down card design (also pre-rounded).

**More images** — hand art, one image set per combination produced by
`DealerAppearance.imageName(for:gesture:)`:
- `hand_m_left_resting`, `hand_m_left_pickingUpDeck`, `hand_m_left_holdingDeck`,
  `hand_m_left_dealing`, `hand_m_left_drawingThree`, `hand_m_left_pointingAtCard`
- Same set again for `hand_m_right_...`, `hand_f_left_...`, `hand_f_right_...`
  (24 images total). `DealerHandOverlayView` currently renders an SF Symbol
  placeholder — swap in `Image("...")` once these exist.

## Audio files you need to add to the bundle

- `shuffle.caf` — reused for both the loud intro shuffle and the quiet
  triple-tap cheat reshuffle (volume is set per call site)
- `croak_deep.caf` — suit-swap consequence
- `ribbit.caf` — face-down-flip consequence
- `frog_snap.caf` — frog catching the critter

## Known gaps to fill in next (intentionally left as skeleton)

- **Move validation / drag-and-drop**: `playTopWasteCard`, `cheatPlayWasteCard`,
  and the tableau tap handlers currently assume a hardcoded destination pile
  (`0`) or take an explicit index. Wire in a real drag gesture or
  tap-to-select-target-pile flow before this is playable end to end.
- **Foundation auto-detection / win condition** isn't implemented yet.
- **Undo/redo** isn't implemented.
- **Frog/critter art** uses SF Symbol placeholders — swap for real sprites.
- **Persistence** (saving an in-progress game) isn't implemented.
- **Android port**: this SwiftUI code doesn't carry over — budget for a
  separate Kotlin/Jetpack Compose build once the iOS/macOS version is solid,
  reusing the same game-logic *design* (CheatEngine/CheatSettings shape)
  rather than the code itself.

## Tuning the cheat system

All frequencies live in `CheatSettings` (`Cheats/CheatSettings.swift`) as
`@Published` properties, so you can eventually expose them in a hidden
developer menu or just edit the defaults directly while playtesting:

- `cheatPointsPerAction` / `minimumCheatPointsForConsequence` — control how
  much cheating it takes before anything visible can happen at all.
- `critterEventChance`, `suitSwapEventChance`, `faceDownFlipEventChance` —
  relative odds once a consequence roll is eligible.
- `normalShuffleVolume` / `cheatShuffleVolume` — loud vs. quiet shuffle.
