import Foundation

enum JournalError: LocalizedError {
    case unusableFolderName(String)
    case couldNotOpen(String)

    var errorDescription: String? {
        switch self {
        case .unusableFolderName(let name):
            return "Cannot derive a sagsnummer from the folder name \"\(name)\"."
        case .couldNotOpen(let name):
            return "No application on this Mac can open \"\(name)\"."
        }
    }
}

/// The per-case journal file, "sag <sagsnummer> -- journal.md", living inside
/// the case folder. Pure naming/creation logic; opening is the caller's job.
enum Journal {
    /// The bit between the number and the extension: "sag 0001 -- journal.md"
    static let baseName = "-- journal"
    static let fileExtension = "md"

    /// "sag 0001 -- AU -- Intune registrering af Mac" -> "0001"
    ///
    /// The sagsnummer is the first whitespace-delimited token after the
    /// "sag " prefix, so it works whether the rest is separated by "--" or "-".
    static func sagsnummer(forFolderNamed name: String) -> String? {
        guard name.hasPrefix(FolderScanner.namePrefix) else { return nil }

        let rest = name.dropFirst(FolderScanner.namePrefix.count)
        guard let token = rest.split(separator: " ").first, !token.isEmpty else { return nil }

        return String(token)
    }

    /// "sag 0001 -- AU -- Intune …" -> "sag 0001 -- journal.md"
    static func fileName(forFolderNamed name: String) -> String? {
        guard let number = sagsnummer(forFolderNamed: name) else { return nil }
        return "sag \(number) \(baseName).\(fileExtension)"
    }

    static func url(for folder: FolderItem) throws -> URL {
        guard let fileName = fileName(forFolderNamed: folder.name) else {
            throw JournalError.unusableFolderName(folder.name)
        }
        return folder.url.appending(path: fileName)
    }

    static func exists(for folder: FolderItem) throws -> Bool {
        let path = try url(for: folder).path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: path)
    }

    /// Creates the journal from the template when it is missing.
    /// - Returns: the file URL and whether it had to be created.
    static func ensureExists(_ folder: FolderItem) throws -> (url: URL, created: Bool) {
        let journalURL = try url(for: folder)
        if FileManager.default.fileExists(atPath: journalURL.path(percentEncoded: false)) {
            return (journalURL, false)
        }
        try template(for: folder).write(to: journalURL, atomically: true, encoding: .utf8)
        return (journalURL, true)
    }

    /// Minimal markdown skeleton; keeps the journal self-describing even when
    /// it is filed away from its folder.
    static func template(for folder: FolderItem) -> String {
        let number = sagsnummer(forFolderNamed: folder.name) ?? "?"
        let created = Date.now.formatted(.iso8601.year().month().day())

        return """
        # sag \(number) \(baseName)

        - Sagsnummer: \(number)
        - Mappe: \(folder.name)
        - Oprettet: \(created)

        ## Log

        """
    }
}
