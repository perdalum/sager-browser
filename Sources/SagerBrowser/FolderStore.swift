import AppKit
import Observation

/// Holds the scanned folders, the window state the menu bar drives, and hands
/// opening off to `NSWorkspace` (LaunchServices — no Apple events).
@MainActor
@Observable
final class FolderStore {
    let settings: AppSettings
    /// Set by `--root` on launch; not persisted, so the preference stays intact.
    private let rootOverride: URL?

    /// What the last scan found, unsorted; `folders` is the sorted view of it.
    private var scanned: [FolderItem] = []
    private(set) var folders: [FolderItem] = []
    private(set) var loadError: String?

    // Window state lives here rather than in the view so menu commands, which
    // have no view context, can drive it.
    var query = ""
    var selection: FolderItem.ID?
    var showingNewSag = false
    /// Title + text of the alert the window should show, if any.
    var errorTitle = "Could not open the journal"
    var errorMessage: String?
    private(set) var searchFocusRequests = 0

    /// Choosing another order re-sorts what is already in memory.
    var sortOrder: SortOrder = .name {
        didSet {
            guard sortOrder != oldValue else { return }
            folders = FolderScanner.sorted(scanned, by: sortOrder)
        }
    }

    var root: URL { rootOverride ?? settings.rootURL }
    var displayRoot: String { FolderScanner.displayPath(root) }
    var visibleFolders: [FolderItem] { FolderScanner.matching(folders, query: query) }

    /// The row the menus and Return act on: the selected one, else the first match.
    var target: FolderItem? {
        if let selection, let hit = visibleFolders.first(where: { $0.id == selection }) {
            return hit
        }
        return visibleFolders.first
    }

    init(settings: AppSettings, rootOverride: URL? = nil) {
        self.settings = settings
        self.rootOverride = rootOverride
        reload()
        selection = visibleFolders.first?.id
    }

    func reload() {
        do {
            scanned = try FolderScanner.scan(root: root)
            loadError = nil
        } catch {
            scanned = []
            loadError = error.localizedDescription
        }
        folders = FolderScanner.sorted(scanned, by: sortOrder)
    }

    // MARK: - Actions shared by the window and the menu bar

    func selectFirstVisible() {
        selection = visibleFolders.first?.id
    }

    /// Opens the folder in Finder (one window, the folder's own contents).
    func openSelection() {
        guard let folder = target else { return }
        selection = folder.id
        open(folder)
    }

    @discardableResult
    func open(_ folder: FolderItem) -> Bool {
        NSWorkspace.shared.open(folder.url)
    }

    /// Opens the case journal, creating it from the template when missing.
    /// `NSWorkspace.open` lets LaunchServices pick the app for `.md`, which is
    /// what "let Finder decide" means here — no hard-coded editor.
    @discardableResult
    func openJournal(for folder: FolderItem) throws -> Bool {
        let (journalURL, created) = try Journal.ensureExists(
            folder,
            template: settings.journalTemplate
        )
        guard NSWorkspace.shared.open(journalURL) else {
            throw JournalError.couldNotOpen(journalURL.lastPathComponent)
        }
        return created
    }

    /// Menu entry point: open the journal of the selected row, reporting any
    /// failure through `errorMessage` so the window can alert.
    func openJournalOfSelection() {
        guard let folder = target else { return }
        selection = folder.id
        do {
            try openJournal(for: folder)
        } catch {
            fail("Could not open the journal", error)
        }
    }

    // MARK: - Dailies

    var isDailiesConfigured: Bool { settings.isDailiesConfigured }

    /// `<dailies folder>/yyyy-MM-dd.md` for today.
    var todayDailiesURL: URL? {
        isDailiesConfigured ? Dailies.url(in: settings.dailiesFolderURL) : nil
    }

    /// Opens today's note, creating it from the template when missing — the
    /// same two-step the journal button uses.
    func openTodaysDailies() {
        guard isDailiesConfigured else {
            errorTitle = "No dailies folder"
            errorMessage = DailiesError.folderNotConfigured.localizedDescription
            return
        }

        do {
            let (url, _) = try Dailies.ensureExists(
                in: settings.dailiesFolderURL,
                template: settings.dailiesTemplate
            )
            guard NSWorkspace.shared.open(url) else {
                throw DailiesError.couldNotOpen(url.lastPathComponent)
            }
        } catch {
            fail("Could not open the dailies", error)
        }
    }

    private func fail(_ title: String, _ error: Error) {
        errorTitle = title
        errorMessage = error.localizedDescription
    }

    func requestNewSag() {
        showingNewSag = true
    }

    func requestSearchFocus() {
        searchFocusRequests += 1
    }

    func clearSearch() {
        query = ""
        requestSearchFocus()
    }
}

/// `--root <path>` for the GUI too, so the app can be pointed at a throwaway
/// tree instead of the real archive.
enum LaunchArguments {
    static func rootOverride(_ arguments: [String]) -> URL? {
        var index = 1

        while index < arguments.count {
            if arguments[index] == "--root", index + 1 < arguments.count {
                return URL(filePath: arguments[index + 1], directoryHint: .isDirectory)
            }
            index += 1
        }

        return nil
    }
}

/// Command-line surface, so scanning, filtering, sorting, journal naming and
/// creation can be checked without a window:
///   SagerBrowser --list [--query hpc] [--root <path>] [--sort name|modified]
///                      [--journals | --ensure-journals]
///   SagerBrowser --list --next                  (next sagsnummer)
///   SagerBrowser --list --create "description"  (creates folder + journal)
enum CommandLineMode {
    static func isRequested(_ arguments: [String]) -> Bool {
        arguments.contains("--list")
    }

    /// "2026-10-26" as typed on the command line.
    private static func parseDay(_ text: String) -> Date? {
        let parts = text.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }

    static func run(_ arguments: [String]) -> Int32 {
        var root = FolderScanner.defaultRoot
        var query = ""
        var reportJournals = false
        var createJournals = false
        var sortOrder = SortOrder.name
        var createDescription: String?
        var printNextNumber = false
        var template = AppSettings.stored().journalTemplate
        var printSettings = false
        var reportDailies = false
        var ensureDailies = false
        var dailiesFolder = AppSettings.stored().dailiesFolderPath
        var day = Date.now
        var index = 1

        while index < arguments.count {
            switch arguments[index] {
            case "--root":
                index += 1
                if index < arguments.count {
                    root = URL(filePath: arguments[index], directoryHint: .isDirectory)
                }
            case "--query":
                index += 1
                if index < arguments.count { query = arguments[index] }
            case "--journals":
                reportJournals = true
            case "--ensure-journals":
                createJournals = true
            case "--sort":
                index += 1
                if index < arguments.count, let parsed = SortOrder(rawValue: arguments[index]) {
                    sortOrder = parsed
                }
            case "--next":
                printNextNumber = true
            case "--template":
                index += 1
                if index < arguments.count { template = arguments[index] }
            case "--settings":
                printSettings = true
            case "--dailies":
                reportDailies = true
            case "--ensure-dailies":
                ensureDailies = true
            case "--dailies-folder":
                index += 1
                if index < arguments.count { dailiesFolder = arguments[index] }
            case "--date":
                index += 1
                if index < arguments.count, let parsed = parseDay(arguments[index]) {
                    day = parsed
                }
            case "--create":
                index += 1
                if index < arguments.count { createDescription = arguments[index] }
            default:
                break
            }
            index += 1
        }

        if printSettings {
            let settings = AppSettings.stored()
            print("root: \(settings.rootPath)")
            print("journal template:")
            print(settings.journalTemplate)
            print("dailies folder: \(settings.dailiesFolderPath)")
            print("dailies template:")
            print(settings.dailiesTemplate)
            return 0
        }

        if reportDailies || ensureDailies {
            let folder = URL(filePath: dailiesFolder, directoryHint: .isDirectory)
            let fileURL = Dailies.url(in: folder, date: day)
            let shown = FolderScanner.displayPath(fileURL)

            if reportDailies {
                let state = Dailies.exists(in: folder, date: day) ? "exists" : "missing"
                print("\(shown) [\(state)]")
                return 0
            }

            let settings = AppSettings.stored()
            do {
                let (url, created) = try Dailies.ensureExists(
                    in: folder,
                    template: settings.dailiesTemplate,
                    date: day
                )
                print("\(FolderScanner.displayPath(url)) [\(created ? "created" : "exists")]")
                return 0
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                return 1
            }
        }

        do {
            let scanned = try FolderScanner.scan(root: root)

            if let createDescription {
                let number = NewSag.nextNumber(after: scanned)
                do {
                    let folder = try NewSag.create(description: createDescription, in: root, number: number)
                    print("created: \(folder.name)")
                    return 0
                } catch {
                    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                    return 1
                }
            }

            if printNextNumber {
                print("next: \(NewSag.formatted(NewSag.nextNumber(after: scanned)))")
                return 0
            }

            let all = FolderScanner.sorted(scanned, by: sortOrder)
            let shown = FolderScanner.matching(all, query: query)
            print("root: \(FolderScanner.displayPath(root))")
            print("sort: \(sortOrder.rawValue), folders: \(all.count), matching: \(shown.count)")

            for folder in shown {
                guard reportJournals || createJournals else {
                    print("  \(folder.name)")
                    continue
                }

                do {
                    if createJournals {
                        let result = try Journal.ensureExists(folder, template: template)
                        print("  \(result.url.lastPathComponent) [\(result.created ? "created" : "exists")] in \(folder.name)")
                    } else {
                        let name = try Journal.url(for: folder).lastPathComponent
                        let state = try Journal.exists(for: folder) ? "exists" : "missing"
                        print("  \(name) [\(state)] in \(folder.name)")
                    }
                } catch {
                    print("  !! \(folder.name): \(error.localizedDescription)")
                }
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
