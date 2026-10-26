# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-26

### Added

- Terminal button on every row, and File ▸ Open in Terminal (⌥⌘T), which opens
  the case folder in Terminal via LaunchServices — a new window already in that
  directory, with no shell script and no Apple events.

## [1.0.0] - 2026-10-26

### Added

- Journal button on every row: opens `sag <sagsnummer> -- journal.md` inside the
  case folder, creating it from a template when missing. Existing files are
  never rewritten.
- New sag (⌘N, or the `+` button): asks for a description and creates
  `sag <next number> -- <description>` plus its journal. Numbers continue from
  the highest existing sagsnummer, so deleted gaps are never reused.
- Sort control in the header and in the View menu (⌘1 by name, ⌘2 by
  modification, newest first).
- Menu bar covering every action, with shortcuts: File (New sag… ⌘N, Open in
  Finder ⌘O, Open Journal ⌘J, Open Today's Dailies ⌘D, Reload ⌘R), Edit (Focus
  Search Field ⌘F, Focus List ⌘L, Clear Search ⇧⌘F), View (sort order).
- Preferences window (⌘,): root folder and journal template, both persisted in
  `UserDefaults` under the explicit suite `local.sagerbrowser.poc`.
- Daily notes (⌘D, or the 📅 button): opens `<dailies folder>/yyyy-MM-dd.md`,
  creating the file from a template and the folder itself when missing.
- Dailies settings: folder and template, with `{dato}`, `{dag}` (Danish
  weekday) and `{uge}` (ISO week) placeholders, plus a live preview.
- App icon, drawn in code by `Tools/make-icon.swift` and packed by
  `Tools/make-icon.sh` into `Resources/AppIcon.icns`; every iconset size is
  rendered directly, with a thicker magnifier ring below 33px.
- MIT license.
- Command-line mode (`SagerBrowser --list …`) that exercises the same scanning,
  filtering, sorting, journal and dailies code as the window: `--root`,
  `--query`, `--sort`, `--next`, `--create`, `--journals`, `--ensure-journals`,
  `--template`, `--settings`, `--dailies`, `--ensure-dailies`,
  `--dailies-folder`, `--date`.
- `--root <path>` on the windowed app as well, so it can be pointed at a
  throwaway tree for testing.

### Changed

- Search terms are **AND**'ed: `chc hpc` matches folders containing both words.
- Menu commands and buttons now act on `FolderStore` directly instead of going
  through `FocusedValues`, so every action works regardless of which view has
  focus.
- The app ships without any configured folder and without a default: the first
  launch asks for a folder, and the folder-dependent items (⌘N, ⌘O, ⌘J, ⌘D) are
  disabled until one is set.
- `Find…` is now `Focus Search Field`, since it only moves focus.
- Esc clears the search field and refocuses it, from either the field or the
  list; inside a sheet Esc still cancels.
- The toolbar `+` and ⟳ buttons no longer carry their own shortcuts, which the
  menu items own.

### Removed

- Hard-coded default paths (`~/OneDrive …`) and the Preferences **Default**
  buttons that restored them. Preferences start empty.

### Fixed

- The footer showed the full home path instead of `~/…`, because
  `homeDirectoryForCurrentUser` keeps a trailing slash.
- Daily note file names were formatted in UTC (`Date.ISO8601FormatStyle`), which
  filed a note started at 00:30 local time under the previous day. Names are
  now built from `Calendar.current` components.

## [0.0.1] - 2026-10-26

### Added

- Initial proof of concept: list the folders starting with `sag ` under a
  configured root, filter them with a search field, and open the selected one in
  Finder on Return or double-click.
- `build.sh` to wrap the SPM executable in a minimal `.app` bundle with an
  ad-hoc signature, so it launches as a normal windowed app.
- Headless `--list` mode for checking the folder logic from a terminal.

<!-- Once published, add the usual compare links here, e.g.
     [1.0.0]: https://github.com/<owner>/SagerBrowser/compare/v0.0.1...v1.0.0 -->
