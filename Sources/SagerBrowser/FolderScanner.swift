import Foundation

/// One row in the list: a folder with a stable identity for `List` selection.
struct FolderItem: Identifiable, Hashable {
    let url: URL

    var id: String { url.path(percentEncoded: false) }
    var name: String { url.lastPathComponent }
}

/// Pure filesystem access — no UI, no Apple events, nothing to authorise.
///
/// Kept separate from the UI so the same logic can be exercised from the
/// command line (`SagerBrowser --list`) and unit-tested later.
enum FolderScanner {
    static let namePrefix = "sag "

    /// ~/OneDrive - Aarhus universitet/pkm/styring/sager
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(
                path: "OneDrive - Aarhus universitet/pkm/styring/sager",
                directoryHint: .isDirectory
            )
    }

    /// Folders directly inside `root` whose name starts with `prefix`,
    /// sorted the way Finder sorts: case-insensitive and number-aware, so
    /// "sag 0002" comes before "sag 0010".
    static func scan(root: URL, prefix: String = namePrefix) throws -> [FolderItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            .map(FolderItem.init(url:))
    }

    /// Case- and diacritic-insensitive substring filter over the folder names.
    ///
    /// The query is split on whitespace and the words are AND'ed: "chc hpc"
    /// matches only folders containing both "chc" **and** "hpc". An empty
    /// (or whitespace-only) query keeps everything.
    static func matching(_ folders: [FolderItem], query: String) -> [FolderItem] {
        let terms = self.terms(in: query)
        guard !terms.isEmpty else { return folders }
        return folders.filter { folder in
            terms.allSatisfy { folder.name.localizedCaseInsensitiveContains($0) }
        }
    }

    /// "chc  hpc " -> ["chc", "hpc"]
    static func terms(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// "/Users/me/OneDrive …/sager/" -> "~/OneDrive …/sager"
    /// (`homeDirectoryForCurrentUser` keeps a trailing slash, so strip both.)
    static func displayPath(_ url: URL) -> String {
        let home = trimmingTrailingSlash(
            FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        )
        let path = trimmingTrailingSlash(url.path(percentEncoded: false))

        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    private static func trimmingTrailingSlash(_ path: String) -> String {
        var trimmed = path
        while trimmed.count > 1 && trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }
}
