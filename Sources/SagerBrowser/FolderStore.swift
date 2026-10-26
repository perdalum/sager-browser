import AppKit
import Observation

/// Holds the scanned folders, the window state the menu bar drives, and hands
/// opening off to `NSWorkspace` (LaunchServices — no Apple events).
@MainActor
@Observable
final class FolderStore {
    let root: URL

    /// What the last scan found, unsorted; `folders` is the sorted view of it.
    private var scanned: [FolderItem] = []
    private(set) var folders: [FolderItem] = []
    private(set) var loadError: String?

    // Window state lives here rather than in the view so menu commands, which
    // have no view context, can drive it.
    var query = ""
    var selection: FolderItem.ID?
    var showingNewSag = false
    var journalError: String?
    private(set) var searchFocusRequests = 0

    /// Choosing another order re-sorts what is already in memory.
    var sortOrder: SortOrder = .name {
        didSet {
            guard sortOrder != oldValue else { return }
            folders = FolderScanner.sorted(scanned, by: sortOrder)
        }
    }

    var displayRoot: String { FolderScanner.displayPath(root) }
    var visibleFolders: [FolderItem] { FolderScanner.matching(folders, query: query) }

    /// The row the menus and Return act on: the selected one, else the first match.
    var target: FolderItem? {
        if let selection, let hit = visibleFolders.first(where: { $0.id == selection }) {
            return hit
        }
        return visibleFolders.first
    }

    init(root: URL = FolderScanner.defaultRoot) {
        self.root = root
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
        let (journalURL, created) = try Journal.ensureExists(folder)
        guard NSWorkspace.shared.open(journalURL) else {
            throw JournalError.couldNotOpen(journalURL.lastPathComponent)
        }
        return created
    }

    /// Menu entry point: open the journal of the selected row, reporting any
    /// failure through `journalError` so the window can alert.
    func openJournalOfSelection() {
        guard let folder = target else { return }
        selection = folder.id
        do {
            try openJournal(for: folder)
        } catch {
            journalError = error.localizedDescription
        }
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
    static func root(_ arguments: [String]) -> URL {
        var root = FolderScanner.defaultRoot
        var index = 1

        while index < arguments.count {
            if arguments[index] == "--root", index + 1 < arguments.count {
                root = URL(filePath: arguments[index + 1], directoryHint: .isDirectory)
                index += 1
            }
            index += 1
        }

        return root
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

    static func run(_ arguments: [String]) -> Int32 {
        var root = FolderScanner.defaultRoot
        var query = ""
        var reportJournals = false
        var createJournals = false
        var sortOrder = SortOrder.name
        var createDescription: String?
        var printNextNumber = false
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
            case "--create":
                index += 1
                if index < arguments.count { createDescription = arguments[index] }
            default:
                break
            }
            index += 1
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
                        let result = try Journal.ensureExists(folder)
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
