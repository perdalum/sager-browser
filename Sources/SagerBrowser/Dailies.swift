import Foundation

/// Today's daily note: `<dailies folder>/yyyy-MM-dd.md`, created from a
/// template when it does not exist yet.
enum Dailies {
    static let fileExtension = "md"

    /// Used until the template is changed in Preferences.
    /// `{dato}`, `{dag}` and `{uge}` are the placeholders.
    static let defaultTemplate = """
    # {dato} ({dag})

    ## Vigtige ting

    ## Andre ting

    """

    /// "2026-10-26" — both the file name and the `{dato}` value. ISO 8601
    /// ordering keeps the folder sorted chronologically in Finder.
    ///
    /// Built from calendar components rather than `Date.ISO8601FormatStyle`,
    /// which formats in UTC: a note started at 00:30 local time would otherwise
    /// be filed under the previous day.
    static func fileName(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }

    /// "torsdag" — Danish weekday for `{dag}`, so it matches the existing notes.
    static func weekday(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .locale(Locale(identifier: "da_DK"))
        )
    }

    /// 44 for `{uge}`; ISO week, which is what a Danish week number means.
    static func week(for date: Date) -> Int {
        Calendar(identifier: .iso8601).component(.weekOfYear, from: date)
    }

    static func url(in folder: URL, date: Date = .now) -> URL {
        folder.appending(path: "\(fileName(for: date)).\(fileExtension)")
    }

    static func exists(in folder: URL, date: Date = .now) -> Bool {
        FileManager.default.fileExists(atPath: url(in: folder, date: date).path(percentEncoded: false))
    }

    /// Fills the placeholders of a (possibly user-edited) template.
    static func render(template: String, date: Date = .now) -> String {
        template
            .replacingOccurrences(of: "{dato}", with: fileName(for: date))
            .replacingOccurrences(of: "{dag}", with: weekday(for: date))
            .replacingOccurrences(of: "{uge}", with: "\(week(for: date))")
    }

    /// Creates today's note when it is missing; creates the folder too, so a
    /// fresh subfolder works without a trip to Finder.
    /// - Returns: the file URL and whether it had to be created.
    static func ensureExists(
        in folder: URL,
        template: String = defaultTemplate,
        date: Date = .now
    ) throws -> (url: URL, created: Bool) {
        let fileURL = url(in: folder, date: date)
        let path = fileURL.path(percentEncoded: false)

        if FileManager.default.fileExists(atPath: path) {
            return (fileURL, false)
        }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try render(template: template, date: date).write(to: fileURL, atomically: true, encoding: .utf8)
        return (fileURL, true)
    }
}

enum DailiesError: LocalizedError {
    case folderNotConfigured
    case couldNotOpen(String)

    var errorDescription: String? {
        switch self {
        case .folderNotConfigured:
            return "No dailies folder is set. Choose one in Settings… (⌘,)."
        case .couldNotOpen(let name):
            return "The dailies file \(name) could not be opened."
        }
    }
}
