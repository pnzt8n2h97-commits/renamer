# Renamer

A simple batch file renaming app for macOS, built with SwiftUI.

- Live preview of every new name
- Find & replace (plain or regex), prefix/suffix, case changes
- Sequence numbering (start, step, padding, position)
- Detects name clashes; handles swaps safely; one-click undo
- Drag & drop files and folders

## Download

Grab the latest `Renamer.dmg` from [Releases](../../releases/latest).

The app is ad-hoc signed, not notarized. On first launch, right-click the app → **Open**.

## Build

Requires Xcode 15+ / Swift 5.9+ on macOS 13+.

```sh
swift run                      # run from source
./scripts/build-dmg.sh 1.0.0   # universal .app + dist/Renamer-1.0.0.dmg
```
