import AppKit

/// Opens a folder in Terminal.
///
/// LaunchServices is asked to open the folder *with* Terminal, which gives a
/// window already sitting in that directory. Nothing is sent to Terminal as an
/// Apple event, so macOS never asks for Automation access — the same reason
/// opening in Finder goes through `NSWorkspace` rather than AppleScript.
enum Terminal {
    static let bundleIdentifier = "com.apple.Terminal"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    static func open(_ folder: URL) async throws {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw TerminalError.notInstalled
        }

        _ = try await NSWorkspace.shared.open(
            [folder],
            withApplicationAt: terminal,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

enum TerminalError: LocalizedError {
    case notInstalled

    var errorDescription: String? {
        "Terminal.app was not found, so the folder could not be opened there."
    }
}
