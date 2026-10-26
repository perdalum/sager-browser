import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`: where the case folders live
/// and the template used whenever a journal file has to be created.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let rootPath = "rootPath"
        static let journalTemplate = "journalTemplate"
    }

    /// Explicit suite: the raw binary and the .app then share one domain
    /// (without it the binary would write a domain named after its argv[0]).
    nonisolated static let suiteName = "local.sagerbrowser.poc"

    nonisolated static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    private let defaults: UserDefaults

    /// Absolute path of the folder that holds the "sag …" folders.
    var rootPath: String {
        didSet { defaults.set(rootPath, forKey: Key.rootPath) }
    }

    /// Markdown template for new journals. `{sagsnummer}`, `{mappe}` and
    /// `{dato}` are substituted; everything else is kept verbatim.
    var journalTemplate: String {
        didSet { defaults.set(journalTemplate, forKey: Key.journalTemplate) }
    }

    nonisolated static var defaultRootPath: String {
        FolderScanner.path(of: FolderScanner.defaultRoot)
    }

    var rootURL: URL {
        URL(filePath: rootPath, directoryHint: .isDirectory)
    }

    var isUsingDefaultRoot: Bool {
        rootPath == Self.defaultRootPath
    }

    var templateIsDefault: Bool {
        journalTemplate == Journal.defaultTemplate
    }

    init(defaults: UserDefaults = AppSettings.sharedDefaults) {
        self.defaults = defaults

        let storedRoot = defaults.string(forKey: Key.rootPath) ?? ""
        rootPath = storedRoot.isEmpty ? Self.defaultRootPath : storedRoot

        let storedTemplate = defaults.string(forKey: Key.journalTemplate) ?? ""
        journalTemplate = storedTemplate.isEmpty ? Journal.defaultTemplate : storedTemplate
    }

    /// Non-isolated read of the persisted values, for the command-line mode.
    nonisolated static func stored(defaults: UserDefaults = AppSettings.sharedDefaults) -> (rootPath: String, journalTemplate: String) {
        let root = defaults.string(forKey: Key.rootPath) ?? ""
        let template = defaults.string(forKey: Key.journalTemplate) ?? ""
        return (
            root.isEmpty ? defaultRootPath : root,
            template.isEmpty ? Journal.defaultTemplate : template
        )
    }

    func resetRoot() {
        rootPath = Self.defaultRootPath
    }

    func resetTemplate() {
        journalTemplate = Journal.defaultTemplate
    }
}
