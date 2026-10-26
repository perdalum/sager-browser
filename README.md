# SagerBrowser — proof of concept

A small SwiftUI macOS app that lists the `sag …` folders in

```
~/OneDrive - Aarhus universitet/pkm/styring/sager
```

filters them as you type, and opens the selected folder in Finder on
**Return** or **double-click**.

This replaces the AppleScript version: no Apple events, so no Automation
permission prompts and none of the `-10004` / `-1700` rough edges.

## Requirements

- macOS 15 or later
- Xcode 16+ / Swift 6 toolchain (`swift build` is enough, no Xcode project)

## Build and run

```bash
cd SagerBrowser
./build.sh
open SagerBrowser.app
```

`build.sh` runs `swift build -c release` and wraps the resulting binary in
`SagerBrowser.app` (Info.plist + ad-hoc code signature).

If your shell is itself sandboxed (CI, some agent shells), SwiftPM cannot use
its `~/Library` caches or apply its own nested build sandbox; pass:

```bash
SWIFT_FLAGS="--disable-sandbox --cache-path .build/spm-cache --scratch-path .build" ./build.sh
```

`swift run SagerBrowser` works too for quick iteration, but that binary is not
inside an `.app`, so LaunchServices treats it as an accessory process.

## Using it

| Action | Result |
| --- | --- |
| Type in the field | case- and diacritic-insensitive substring filter; space-separated words are AND'ed (`chc hpc` = "chc" **and** "hpc"); the first match is selected automatically |
| ↑ / ↓ | move the selection |
| Return | open the selected folder (works from the search field *and* from the list) |
| Double-click a row | open that folder |
| Esc in the field | (system default) clears focus, not the query — use the ⊗ button to clear |
| ⌘R | rescan the folder |

The header shows `matches/total`, the footer shows the scanned path and the
open hint.

## Headless check (no window)

```bash
.build/release/SagerBrowser --list
.build/release/SagerBrowser --list --query hpc
.build/release/SagerBrowser --list --root /tmp/somedir --query x
```

Prints the root, the counts and the matching names; exits `1` with a message
when the root cannot be read. This is the same code path the window uses, which
is how the folder logic can be verified without a GUI session.

## Layout

```
SagerBrowser/
├── Package.swift
├── Sources/SagerBrowser/
│   ├── SagerBrowserApp.swift   @main, window, ⌘R command
│   ├── ContentView.swift       search bar, list, footer
│   ├── FolderStore.swift       observable state, NSWorkspace open, CLI mode
│   └── FolderScanner.swift     pure scanning/filtering/sorting/path display
├── Resources/Info.plist
├── build.sh
└── README.md
```

## Design notes

- **Opening:** `NSWorkspace.shared.open(folderURL)` — the LaunchServices path.
  Finder brings up the folder; nothing is sent to Finder as an Apple event, so
  macOS never asks for Automation access.
- **Scanning:** `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:)`
  with `isDirectoryKey`. Names must start with `sag ` (case-sensitive, trailing
  space included) and be real folders; hidden entries are skipped.
- **Sorting:** `localizedStandardCompare`, the Finder-like ordering that keeps
  `sag 0002` before `sag 0010`.
- **Filtering:** the query is split on whitespace (`FolderScanner.terms(in:)`)
  and the words are **AND'ed** with `localizedCaseInsensitiveContains`. So
  `intune` matches `sag 0001 -- AU -- Intune registrering af Mac`, and
  `chc hpc` matches only folders containing both words (3 of 69 here:
  `sag 0017`, `sag 0018`, `sag 0078`). For OR semantics, swap
  `terms.allSatisfy` for `terms.contains`.
- **Home folder:** `FileManager.homeDirectoryForCurrentUser` (the Swift
  equivalent of AppleScript's `path to home folder`); the footer shortens it
  to `~/…`.

## Known limitations (fine for a POC)

- No file-system watcher: new OneDrive folders show up after ⌘R or relaunch.
- Single selection only; no "reveal in parent folder"; no sorting controls.
- Ad-hoc signed, so it runs locally but is not distributable as-is
  (that would need Developer ID signing and notarisation).
