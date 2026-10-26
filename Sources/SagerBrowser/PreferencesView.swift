import AppKit
import SwiftUI

/// Preferences (⌘,): where the case folders live and the journal template.
struct PreferencesView: View {
    @Environment(FolderStore.self) private var store

    private var settings: AppSettings { store.settings }

    var body: some View {
        Form {
            Section("Sager") {
                LabeledContent("Root folder") {
                    HStack(spacing: 6) {
                        TextField("Path", text: rootPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .onSubmit { store.reload() }

                        Button("Choose…") { chooseRoot() }
                        Button("Default") {
                            settings.resetRoot()
                            store.reload()
                        }
                        .disabled(settings.isUsingDefaultRoot)
                    }
                }

                Text(rootStatus)
                    .font(.caption)
                    .foregroundStyle(rootExists ? Color.secondary : Color.red)
            }

            Section("Journal template") {
                TextEditor(text: journalTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary)
                    }

                HStack {
                    Text("Placeholders: {sagsnummer}, {mappe}, {dato}")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Restore Default") {
                        settings.resetTemplate()
                    }
                    .disabled(settings.templateIsDefault)
                }

                DisclosureGroup("Preview") {
                    Text(preview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 520)
        .onChange(of: settings.rootPath) { store.reload() }
    }

    // MARK: - Bindings

    private var rootPath: Binding<String> {
        Binding(get: { settings.rootPath }, set: { settings.rootPath = $0 })
    }

    private var journalTemplate: Binding<String> {
        Binding(get: { settings.journalTemplate }, set: { settings.journalTemplate = $0 })
    }

    // MARK: - Derived values

    private var rootExists: Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: settings.rootPath,
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    private var rootStatus: String {
        if let error = store.loadError {
            return error
        }
        if !rootExists {
            return "Folder not found: \(settings.rootPath)"
        }
        return "\(store.folders.count) folders starting with \"sag \""
    }

    private var preview: String {
        let sample = store.folders.first
            ?? FolderItem(
                url: settings.rootURL.appending(path: "sag 0001 -- eksempel"),
                modified: .now
            )
        return Journal.render(template: settings.journalTemplate, for: sample)
    }

    // MARK: - Actions

    private func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.rootURL
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.rootPath = FolderScanner.path(of: url)
        store.reload()
    }
}

#Preview {
    PreferencesView()
        .environment(FolderStore(settings: AppSettings()))
}
