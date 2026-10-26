import SwiftUI

/// Every action the app offers, as menu items with keyboard shortcuts.
///
/// The commands talk to `FolderStore` directly instead of pulling state out of
/// the window, so they work regardless of which view currently has focus.
struct SagerCommands: Commands {
    let store: FolderStore

    var body: some Commands {
        // File > New sag… (⌘N)
        CommandGroup(replacing: .newItem) {
            Button("New sag…") { store.requestNewSag() }
                .keyboardShortcut("n", modifiers: .command)
        }

        // File > Open in Finder (⌘O), Open Journal (⌘J), Reload (⌘R)
        CommandGroup(after: .newItem) {
            Divider()
            Button("Open in Finder") { store.openSelection() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(store.target == nil)
            Button("Open Journal") { store.openJournalOfSelection() }
                .keyboardShortcut("j", modifiers: .command)
                .disabled(store.target == nil)
            Button("Open Today's Dailies") { store.openTodaysDailies() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!store.isDailiesConfigured)
            Divider()
            Button("Reload") {
                store.reload()
                store.selectFirstVisible()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        // Edit > Focus Search Field (⌘F), Focus List (⌘L), Clear Search (⇧⌘F)
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Focus Search Field") { store.requestSearchFocus() }
                .keyboardShortcut("f", modifiers: .command)
            Button("Focus List") { store.requestListFocus() }
                .keyboardShortcut("l", modifiers: .command)
            Button("Clear Search") { store.clearSearch() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        // View > Sort by Name (⌘1) / Sort by Modified (⌘2)
        CommandGroup(after: .sidebar) {
            Divider()
            Toggle("Sort by Name", isOn: sortIs(.name))
                .keyboardShortcut("1", modifiers: .command)
            Toggle("Sort by Modified", isOn: sortIs(.modified))
                .keyboardShortcut("2", modifiers: .command)
        }
    }

    /// A menu checkmark that only ever turns on: toggles render as native
    /// checkmark items and, unlike picker rows, can carry a shortcut.
    private func sortIs(_ order: SortOrder) -> Binding<Bool> {
        Binding(
            get: { store.sortOrder == order },
            set: { isOn in if isOn { store.sortOrder = order } }
        )
    }
}
