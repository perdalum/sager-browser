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
    @State private var store = FolderStore(root: LaunchArguments.root(CommandLine.arguments))

    var body: some Scene {
        WindowGroup("Sager") {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 680, height: 520)
        .commands {
            SagerCommands(store: store)
        }
    }
}
