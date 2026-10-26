# SagerBrowser — proof of concept

A small SwiftUI macOS app that lists the `sag …` case folders in a folder you
choose, filters them as you type, and opens the selected folder in Finder on
**Return** or **double-click**. It also opens each case's Markdown journal and
today's daily note, creating either from a template when it is missing.

The app ships **without any configured folder and without a default**: the
first launch asks you to point it at a folder (⌘,) instead of guessing at a
personal path.

This replaces the AppleScript version: no Apple events, so no Automation
permission prompts and none of the `-10004` / `-1700` rough edges.

![Sager icon](Resources/icon-1024.png)

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
| ⌘F / ⌘L | move keyboard focus to the search field / to the folder list |
| ↑ / ↓ | move the selection (the list must have focus) |
| Return | open the selected folder (works from the search field *and* from the list) |
| Double-click a row | open that folder |
| 📄 button on a row | open `sag <sagsnummer> -- journal.md` from that folder; created from a template if missing |
| Esc | clear the search field and put the caret back in it (works from the field and from the list); in a sheet, Esc still cancels the sheet |
| + (⌘N) | new sag: asks for a description, creates `sag <next> -- <description>` and its journal, selects the new folder |
| 📅 button (header) | open today's daily note `yyyy-MM-dd.md` in the dailies folder, created from a template if missing |
| Name / Modified (header) | segmented control: sort by folder name, or newest modification first |
| ⌘R | rescan the folder |

The header shows `matches/total`, the footer shows the scanned path and the
open hint.

## Menus and shortcuts

| Menu | Item | Shortcut |
| --- | --- | --- |
| File | New sag… | ⌘N |
| File | Open in Finder | ⌘O |
| File | Open Journal | ⌘J |
| File | Open Today's Dailies | ⌘D |
| File | Reload | ⌘R |
| Edit | Focus Search Field | ⌘F |
| Edit | Focus List | ⌘L |
| Edit | Clear Search | ⇧⌘F |
| View | Sort by Name | ⌘1 |
| View | Sort by Modified | ⌘2 |

The window's state (query, selection, sheet flags) lives in `FolderStore`, so the
menu items drive the same actions the buttons do instead of going through
`FocusedValues` — they stay enabled even while a different control has focus.

## Preferences (⌘,)

**App ▸ Settings…** opens two settings, both persisted in `UserDefaults`
(domain `local.sagerbrowser.poc`, so the raw binary and the `.app` agree):

| Setting | Out of the box | Effect |
| --- | --- | --- |
| Root folder | *unset* | which folder is scanned; **Choose…** opens a folder panel and editing the path rescans immediately. Until it is set the window shows "No folder chosen" with a button to these settings, and ⌘N/⌘O/⌘J are disabled. |
| Journal template | the skeleton below | contents of a journal file created from scratch |
| Dailies folder | *unset* | where `yyyy-MM-dd.md` lives; **Choose…** picks it. Until it is set ⌘D is disabled. A missing folder is created on first use. |
| Dailies template | `# {dato} ({dag})` + sections | contents of a daily note created from scratch |

The template placeholders are `{sagsnummer}`, `{mappe}` and `{dato}`; everything
else is written verbatim. The default is

```markdown
# sag {sagsnummer} -- journal

- Sagsnummer: {sagsnummer}
- Mappe: {mappe}
- Oprettet: {dato}

## Log
```

The dailies template uses `{dato}` (`yyyy-MM-dd`), `{dag}` (Danish weekday) and
`{uge}` (ISO week number); its default is

```markdown
# {dato} ({dag})

## Vigtige ting

## Andre ting
```

An existing journal or daily note is never rewritten, so changing a template
only affects files created later. Both sections show a live preview: journals
render against the first folder in the current list, dailies against today.

`--root <path>` on the command line overrides the preference for that launch
only; it is not saved back.

## Headless check (no window)

```bash
.build/release/SagerBrowser --list
.build/release/SagerBrowser --list --query hpc
.build/release/SagerBrowser --list --root /tmp/somedir --query x
.build/release/SagerBrowser --list --sort modified     # name | modified (default name)
.build/release/SagerBrowser --list --next             # next sagsnummer, creates nothing
.build/release/SagerBrowser --list --create "AU -- text" --root /tmp/x   # create folder + journal
.build/release/SagerBrowser --list --journals          # journal name + exists/missing, creates nothing
.build/release/SagerBrowser --list --ensure-journals   # create missing journals (combine with --root to sandbox it)
.build/release/SagerBrowser --list --settings         # the persisted preferences
.build/release/SagerBrowser --list --ensure-journals --root /tmp/x --template 'Hi {sagsnummer} on {dato}'
.build/release/SagerBrowser --list --dailies --dailies-folder /tmp/d --date 2026-01-02   # path + exists/missing
.build/release/SagerBrowser --list --ensure-dailies --dailies-folder /tmp/d --date 2026-01-02  # create it
```

`--settings` prints all four persisted values. `--date` takes a `yyyy-MM-dd`
date so the file name, weekday and week number can be checked for any day.

Prints the root, the counts and the matching names. Without `--root` it uses the
configured folder, and with neither it exits `1` telling you to pass `--root` —
there is no built-in default to fall back on. This is the same code path the window uses, which
is how the folder logic can be verified without a GUI session.

## Icon

`Resources/AppIcon.icns` is generated, not hand-drawn in an editor: a blue-violet
rounded square with a folder, a page peeking out (the journal) and a magnifier.
`Tools/make-icon.swift` draws it with AppKit vector code in an 824pt design box
(Apple's padding for the shadow) and renders **every iconset size directly**, so
16px and 32px are not downsampled mush — the ring and handle are thickened below
33px and the page rules are dropped there.

```bash
./Tools/make-icon.sh     # -> Resources/AppIcon.icns + Resources/icon-1024.png
```

`build.sh` copies the `.icns` into the bundle; `CFBundleIconFile` in
`Resources/Info.plist` points at it. The generated PNG is in the repo for the
preview above; the iconset intermediates live in `.build/`.

## Layout

```
SagerBrowser/
├── CHANGELOG.md
├── Package.swift
├── Sources/SagerBrowser/
│   ├── SagerBrowserApp.swift   @main, window scene, Settings scene
│   ├── ContentView.swift       search bar, list, footer
│   ├── FolderStore.swift       observable state, NSWorkspace open, CLI mode
│   ├── AppSettings.swift       persisted folders + templates (no defaults)
│   ├── PreferencesView.swift   ⌘, window: folders, templates, previews
│   ├── Journal.swift           journal file naming + template rendering
│   ├── Dailies.swift           yyyy-MM-dd.md naming, weekdays, ISO week
│   ├── NewSag.swift           next number, folder + journal creation
│   ├── NewSagSheet.swift      "New sag" sheet (description field)
│   ├── SagerCommands.swift     menu bar items + keyboard shortcuts
│   └── FolderScanner.swift     pure scanning/filtering/sorting/path display
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns            generated by Tools/make-icon.sh
│   └── icon-1024.png           preview, same tool
├── Tools/
│   ├── make-icon.swift         AppKit drawing of the icon
│   └── make-icon.sh            every iconset size -> .icns
├── build.sh
└── README.md
```

## Design notes

- **Opening:** `NSWorkspace.shared.open(folderURL)` — the LaunchServices path.
  Finder brings up the folder; nothing is sent to Finder as an Apple event, so
  macOS never asks for Automation access.
- **New sag:** the next number is `max(existing sagsnummer) + 1`, zero-padded to
  four digits (`0079`), so gaps left by deleted cases are never reused. The
  folder is `sag <nummer> -- <description>` and its journal is created in the
  same step; a description containing `/` or an empty one is refused before
  anything is written.
- **Journal:** `<case folder>/sag <sagsnummer> -- journal.md`. The sagsnummer is
  the first whitespace-delimited token after `sag ` in the folder name, so
  `sag 0033 - AU -- DeiC-DM` still gives `sag 0033 -- journal.md`. A missing
  file is written by `Journal.render(template:for:)` from the template in
  Preferences (`{sagsnummer}`, `{mappe}`, `{dato}` placeholders); an existing
  one is never touched. Opening goes
  through `NSWorkspace.shared.open`, so LaunchServices — not the app — decides
  which editor a `.md` opens in.
- **Dailies:** `<dailies folder>/yyyy-MM-dd.md` for today. The name is built
  from `Calendar.current` components rather than `Date.ISO8601FormatStyle`, which
  formats in UTC — a note started at 00:30 local time would otherwise be filed
  under the previous day. `{dag}` is the Danish weekday (`torsdag`), matching the
  Danish weekday names, and `{uge}` is the ISO week. A missing dailies
  folder is created with `createDirectory(withIntermediateDirectories:)`, so a
  fresh subfolder needs no setup; an existing file is opened untouched.
- **Scanning:** `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:)`
  with `isDirectoryKey`. Names must start with `sag ` (case-sensitive, trailing
  space included) and be real folders; hidden entries are skipped.
- **Sorting:** by name uses `localizedStandardCompare`, the Finder-like ordering
  that keeps `sag 0002` before `sag 0010`. By modification it is newest first
  (`contentModificationDate` of the folder itself), with name order as the
  tie-break — folders written in one batch share a timestamp, so the tie-break
  does real work. Changing the order re-sorts what is already in memory; ⌘R is
  only needed to rescan.
- **Filtering:** the query is split on whitespace (`FolderScanner.terms(in:)`)
  and the words are **AND'ed** with `localizedCaseInsensitiveContains`. So
  `intune` matches `sag 0001 -- Eksempel -- Intune registrering`, and
  `chc hpc` matches only folders containing both words, so
  `sag 0017 -- Eksempel -- chc hpc` matches but `sag 0020 -- chc` does not.
  For OR semantics, swap `terms.allSatisfy` for `terms.contains`.
- **Home folder:** `FileManager.homeDirectoryForCurrentUser` is used only as the
  starting point for the folder panel and for `~/…` shortening in the footer.
  No personal path is compiled into the app: `AppSettings.rootPath` starts empty
  and everything that needs a folder is disabled until one is chosen.
- **Settings:** `AppSettings` is an `@Observable` wrapper over an explicit
  `UserDefaults(suiteName: "local.sagerbrowser.poc")`. It is passed into
  `FolderStore`, which reads `root` and the journal template from it, so there is
  one source of truth for both the window and the menu bar.

## License

MIT — see [LICENSE](LICENSE). The icon in `Resources/` is part of the same
license; it is generated by `Tools/make-icon.swift`, not third-party artwork.

## Known limitations (fine for a POC)

- No file-system watcher: new folders show up after ⌘R or relaunch.
- Single selection only; no "reveal in parent folder"; no per-case notes or tags.
- Dailies only ever open *today's* note; there is no picker for another date.
- Ad-hoc signed, so it runs locally but is not distributable as-is
  (that would need Developer ID signing and notarisation).
