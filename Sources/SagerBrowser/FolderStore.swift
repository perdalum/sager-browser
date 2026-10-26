import AppKit
import Observation

/// Holds the scanned folders and hands opening off to `NSWorkspace`,
/// which is the LaunchServices path — no Apple events, no Automation prompt.
@MainActor
@Observable
final class FolderStore {
    let root: URL
    private(set) var folders: [FolderItem] = []
    private(set) var loadError: String?

    var displayRoot: String { FolderScanner.displayPath(root) }

    init(root: URL = FolderScanner.defaultRoot) {
        self.root = root
        reload()
    }

    func reload() {
        do {
            folders = try FolderScanner.scan(root: root)
            loadError = nil
        } catch {
            folders = []
            loadError = error.localizedDescription
        }
    }

    /// Opens the folder in Finder (one window, the folder's own contents).
    @discardableResult
    func open(_ folder: FolderItem) -> Bool {
        NSWorkspace.shared.open(folder.url)
    }

    /// Opens the case journal, creating it from the template when missing.
    /// `NSWorkspace.open` lets LaunchServices pick the app for `.md`, which is
    /// what "let Finder decide" means here — no hard-coded editor.
    /// - Returns: true when the file had to be created.
    @discardableResult
    func openJournal(for folder: FolderItem) throws -> Bool {
        let (journalURL, created) = try Journal.ensureExists(folder)
        guard NSWorkspace.shared.open(journalURL) else {
            throw JournalError.couldNotOpen(journalURL.lastPathComponent)
        }
        return created
    }
}

/// Command-line surface, so the scanning, filtering and journal naming can be
/// checked without a window:
///   SagerBrowser --list [--query hpc] [--root <path>] [--journals | --ensure-journals]
enum CommandLineMode {
    static func isRequested(_ arguments: [String]) -> Bool {
        arguments.contains("--list")
    }

    static func run(_ arguments: [String]) -> Int32 {
        var root = FolderScanner.defaultRoot
        var query = ""
        var reportJournals = false
        var createJournals = false
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
            default:
                break
            }
            index += 1
        }

        do {
            let all = try FolderScanner.scan(root: root)
            let shown = FolderScanner.matching(all, query: query)
            print("root: \(FolderScanner.displayPath(root))")
            print("folders: \(all.count), matching: \(shown.count)")

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
