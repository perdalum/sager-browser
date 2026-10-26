import Foundation

/// One row in the list: a folder with a stable identity for `List` selection
/// and the modification date the "Modified" sort needs.
struct FolderItem: Identifiable, Hashable {
    let url: URL
    let modified: Date

    var id: String { url.path(percentEncoded: false) }
    var name: String { url.lastPathComponent }
}

/// How the rows are ordered.
enum SortOrder: String, CaseIterable, Identifiable {
    /// Finder-like alphabetical order, number-aware ("sag 0002" before "sag 0010").
    case name
    /// Most recently modified folder first, ties broken by name.
    case modified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .modified: return "Modified"
        }
    }

    var systemImage: String {
        switch self {
        case .name: return "textformat.abc"
        case .modified: return "clock"
        }
    }
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

    /// Folders directly inside `root` whose name starts with `prefix`.
    /// Returned in no particular order; `sorted(_:by:)` applies the choice.
    static func scan(root: URL, prefix: String = namePrefix) throws -> [FolderItem] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .compactMap { url in
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isDirectory == true else { return nil }
                return FolderItem(
                    url: url,
                    modified: values.contentModificationDate ?? .distantPast
                )
            }
    }

    static func sorted(_ folders: [FolderItem], by order: SortOrder) -> [FolderItem] {
        switch order {
        case .name:
            return byName(folders)
        case .modified:
            return folders.sorted { lhs, rhs in
                if lhs.modified != rhs.modified {
                    return lhs.modified > rhs.modified   // newest first
                }
                return byNameOrder(lhs, rhs)
            }
        }
    }

    private static func byName(_ folders: [FolderItem]) -> [FolderItem] {
        folders.sorted(by: byNameOrder)
    }

    private static func byNameOrder(_ lhs: FolderItem, _ rhs: FolderItem) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
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

    /// Absolute path without a trailing slash.
    static func path(of url: URL) -> String {
        trimmingTrailingSlash(url.path(percentEncoded: false))
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
