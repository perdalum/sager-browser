import SwiftUI

@main
enum SagerBrowserMain {
    static func main() {
        let arguments = CommandLine.arguments

        // Headless mode for checking the scanning/filtering from a terminal.
        if CommandLineMode.isRequested(arguments) {
            exit(CommandLineMode.run(arguments))
        }

        SagerBrowserApp.main()
    }
}

struct SagerBrowserApp: App {
    @State private var store = FolderStore()

    var body: some Scene {
        WindowGroup("Sager") {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 680, height: 520)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Reload") {
                    store.reload()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
