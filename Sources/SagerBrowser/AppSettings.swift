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
        static let dailiesFolderPath = "dailiesFolderPath"
        static let dailiesTemplate = "dailiesTemplate"
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

    /// Folder for the daily notes ("<dailies>/yyyy-MM-dd.md").
    var dailiesFolderPath: String {
        didSet { defaults.set(dailiesFolderPath, forKey: Key.dailiesFolderPath) }
    }

    /// Markdown template for new dailies. `{dato}`, `{dag}` and `{uge}` are
    /// substituted.
    var dailiesTemplate: String {
        didSet { defaults.set(dailiesTemplate, forKey: Key.dailiesTemplate) }
    }

    /// Nothing is configured until the user picks a folder; there is no
    /// baked-in default, so the app carries no personal paths.
    var isRootConfigured: Bool {
        !rootPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var rootURL: URL? {
        isRootConfigured ? URL(filePath: rootPath, directoryHint: .isDirectory) : nil
    }

    var dailiesFolderURL: URL? {
        isDailiesConfigured ? URL(filePath: dailiesFolderPath, directoryHint: .isDirectory) : nil
    }

    /// The daily-note feature needs a folder before it can do anything.
    var isDailiesConfigured: Bool {
        !dailiesFolderPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var templateIsDefault: Bool {
        journalTemplate == Journal.defaultTemplate
    }

    var dailiesTemplateIsDefault: Bool {
        dailiesTemplate == Dailies.defaultTemplate
    }

    init(defaults: UserDefaults = AppSettings.sharedDefaults) {
        self.defaults = defaults

        rootPath = defaults.string(forKey: Key.rootPath) ?? ""

        let storedTemplate = defaults.string(forKey: Key.journalTemplate) ?? ""
        journalTemplate = storedTemplate.isEmpty ? Journal.defaultTemplate : storedTemplate

        dailiesFolderPath = defaults.string(forKey: Key.dailiesFolderPath) ?? ""

        let storedDailiesTemplate = defaults.string(forKey: Key.dailiesTemplate) ?? ""
        dailiesTemplate = storedDailiesTemplate.isEmpty
            ? Dailies.defaultTemplate
            : storedDailiesTemplate
    }

    /// Non-isolated read of the persisted values, for the command-line mode.
    nonisolated static func stored(
        defaults: UserDefaults = AppSettings.sharedDefaults
    ) -> (rootPath: String, journalTemplate: String, dailiesFolderPath: String, dailiesTemplate: String) {
        let root = defaults.string(forKey: Key.rootPath) ?? ""
        let template = defaults.string(forKey: Key.journalTemplate) ?? ""
        let dailies = defaults.string(forKey: Key.dailiesFolderPath) ?? ""
        let dailiesTemplate = defaults.string(forKey: Key.dailiesTemplate) ?? ""
        return (
            root,
            template.isEmpty ? Journal.defaultTemplate : template,
            dailies,
            dailiesTemplate.isEmpty ? Dailies.defaultTemplate : dailiesTemplate
        )
    }

    func resetTemplate() {
        journalTemplate = Journal.defaultTemplate
    }

    func resetDailiesTemplate() {
        dailiesTemplate = Dailies.defaultTemplate
    }
}
