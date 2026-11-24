# Working in this repo

Embarrass Me Not is a macOS menu bar app, open source (Apache 2.0; the name
and icon reserved in `NOTICE`) at github.com/wtermini/embarrassmenot, and
perhaps on the Mac App Store later. Bundle ID `me.termini.embarrassmenot`.
Its mascot is a small, fluffy white spitz, drawn in code by `Art/draw.py`
(`make icons`): good in the app icon (`EmbarrassMeNot/AppIcon.icon`, Icon
Composer's format, which Xcode also turns into the older `.icns`) and in the
menu bar while all is quiet, barking in the menu bar while background sounds
play. Icons are our own drawings, never SF Symbols.

- **The App Store build uses public APIs only.** Anything private (today only
  Apple's Background Sounds, `EmbarrassMeNot/BackgroundSounds.swift`) is behind
  `#if BACKGROUND_SOUNDS`, which `Config/AppStore.xcconfig` leaves unset.
  After `make appstore`, `strings` on the binary must find no
  `HearingUtilities` or `ComfortSound`. No switches or flags
  that change what a store build does: App Review treats those as hidden
  features (Guideline 5.6).
- **Never bundle Apple's sound files**; the build from source asks macOS to
  play its own copies, and the App Store build makes its own sounds.
- **It must build from a clean clone with only Xcode**: no package manager,
  no generator, no third-party dependencies, and no Apple account needed
  (signing defaults to "Sign to Run Locally"; a team goes in the ignored
  `Config/Local.xcconfig`).
- Logic goes in `Core/` with tests (`make test`); the app target stays thin.
- Debug builds only: `EMBARRASSMENOT_SNAPSHOT=menu.png` (and
  `EMBARRASSMENOT_DARK=1`) draws the menu to a file and quits, for looking
  at it without clicking.
- Nothing leaves the Mac: no network requests, analytics or accounts.
