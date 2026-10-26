import Foundation

enum NewSagError: LocalizedError {
    case emptyDescription
    case slashInDescription
    case alreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .emptyDescription:
            return "A description is required."
        case .slashInDescription:
            return "The description cannot contain \"/\" — it becomes a folder name."
        case .alreadyExists(let name):
            return "A folder named \"\(name)\" already exists."
        }
    }
}

/// Creating a new case: pick the next free number, then make the folder and
/// its journal. Deliberately free of UI so it can be exercised from the CLI.
enum NewSag {
    /// Existing numbers are four digits wide (0001 … 0078), so keep that shape.
    static let numberWidth = 4

    /// Highest existing sagsnummer + 1. Gaps are not reused, so a deleted
    /// "sag 0046" never comes back and numbers stay unique over time.
    static func nextNumber(after folders: [FolderItem]) -> Int {
        let highest = folders
            .compactMap { Journal.sagsnummer(forFolderNamed: $0.name) }
            .compactMap(Int.init)
            .max() ?? 0
        return highest + 1
    }

    static func formatted(_ number: Int) -> String {
        String(format: "%0\(numberWidth)d", number)
    }

    /// "sag 0079 -- <description>"
    static func folderName(number: Int, description: String) -> String {
        "sag \(formatted(number)) -- \(description.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// Creates the case folder and its journal file.
    @discardableResult
    static func create(description: String, in root: URL, number: Int) throws -> FolderItem {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NewSagError.emptyDescription }
        guard !trimmed.contains("/") else { throw NewSagError.slashInDescription }

        let name = folderName(number: number, description: trimmed)
        let url = root.appending(path: name, directoryHint: .isDirectory)

        guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw NewSagError.alreadyExists(name)
        }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)

        // Journal.ensureExists writes the template; the folder is brand new,
        // so this always creates the file.
        let folder = FolderItem(url: url, modified: .now)
        _ = try Journal.ensureExists(folder)

        return folder
    }
}
