import SwiftUI

/// Search field on top, one row per matching folder below.
/// Return or a double-click opens the row's folder in Finder.
struct ContentView: View {
    @Environment(FolderStore.self) private var store

    @State private var query = ""
    @State private var selection: FolderItem.ID?
    @State private var journalError: String?
    @FocusState private var searchFocused: Bool

    private var visible: [FolderItem] {
        FolderScanner.matching(store.folders, query: query)
    }

    /// The row Return should act on: the selected one, else the first match.
    private var target: FolderItem? {
        if let selection, let hit = visible.first(where: { $0.id == selection }) {
            return hit
        }
        return visible.first
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
            Divider()
            statusBar
        }
        .frame(minWidth: 580, minHeight: 440)
        .onAppear {
            searchFocused = true
            selection = visible.first?.id
        }
        .onChange(of: query) {
            selection = visible.first?.id
        }
        .alert("Could not open the journal", isPresented: showingJournalError) {
            Button("OK", role: .cancel) { journalError = nil }
        } message: {
            Text(journalError ?? "")
        }
    }

    private var showingJournalError: Binding<Bool> {
        Binding(
            get: { journalError != nil },
            set: { if !$0 { journalError = nil } }
        )
    }

    // MARK: - Header

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search folders (space = all words)", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit(openSelection)

            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            Divider()
                .frame(height: 14)

            Text("\(visible.count)/\(store.folders.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .help("Showing \(visible.count) of \(store.folders.count) folders")

            Button {
                store.reload()
                selection = visible.first?.id
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if let error = store.loadError {
            ContentUnavailableView {
                Label("Folder not available", systemImage: "folder.badge.questionmark")
            } description: {
                Text("\(store.displayRoot)\n\n\(error)")
            } actions: {
                Button("Try Again") { store.reload() }
            }
        } else if visible.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            folderList
        }
    }

    private var folderList: some View {
        List(visible, selection: $selection) { folder in
            row(folder)
        }
        .listStyle(.inset)
        .onKeyPress(.return) {
            openSelection()
            return .handled
        }
    }

    private func row(_ folder: FolderItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
            Text(folder.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)

            Button {
                openJournal(folder)
            } label: {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(journalHelp(for: folder))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // simultaneousGesture keeps List's own single-click selection working.
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selection = folder.id
                store.open(folder)
            }
        )
    }

    /// "Open sag 0001 -- journal.md (created if missing)"
    private func journalHelp(for folder: FolderItem) -> String {
        let name = Journal.fileName(forFolderNamed: folder.name) ?? "the journal"
        return "Open \(name) — created from a template if missing"
    }

    private func openJournal(_ folder: FolderItem) {
        do {
            try store.openJournal(for: folder)
        } catch {
            journalError = error.localizedDescription
        }
    }

    // MARK: - Footer

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(store.displayRoot)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            Text("⏎ or double-click opens")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func openSelection() {
        guard let folder = target else { return }
        selection = folder.id
        store.open(folder)
    }
}

#Preview {
    ContentView()
        .environment(FolderStore(root: FolderScanner.defaultRoot))
}
