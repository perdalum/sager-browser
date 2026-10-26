import SwiftUI

/// Search field on top, one row per matching folder below.
/// Return or a double-click opens the row's folder in Finder.
///
/// All window state lives in `FolderStore`, so the menu bar can drive the same
/// actions without this view having to publish anything.
struct ContentView: View {
    @Environment(FolderStore.self) private var store
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    private var visible: [FolderItem] { store.visibleFolders }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
            Divider()
            statusBar
        }
        .frame(minWidth: 580, minHeight: 440)
        .onAppear { searchFocused = true }
        .onChange(of: store.query) { store.selectFirstVisible() }
        .onChange(of: store.searchFocusRequests) { searchFocused = true }
        .onChange(of: store.listFocusRequests) { listFocused = true }
        .sheet(isPresented: showingNewSag) {
            NewSagSheet(
                root: store.root,
                number: NewSag.nextNumber(after: store.folders),
                template: store.settings.journalTemplate,
                onCreate: { folder in
                    store.reload()
                    store.selection = folder.id
                }
            )
        }
        .alert(store.errorTitle, isPresented: showingError) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Bindings into the store

    private var searchText: Binding<String> {
        Binding(get: { store.query }, set: { store.query = $0 })
    }

    private var selectedRow: Binding<FolderItem.ID?> {
        Binding(get: { store.selection }, set: { store.selection = $0 })
    }

    private var sortBinding: Binding<SortOrder> {
        Binding(get: { store.sortOrder }, set: { store.sortOrder = $0 })
    }

    private var showingNewSag: Binding<Bool> {
        Binding(get: { store.showingNewSag }, set: { store.showingNewSag = $0 })
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    // MARK: - Header

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search folders (space = all words)", text: searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { store.openSelection() }

            if !store.query.isEmpty {
                Button {
                    store.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search (⇧⌘F)")
            }

            Divider()
                .frame(height: 14)

            Picker("Sort", selection: sortBinding) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 140)
            .help("Sort rows by folder name (⌘1) or last modification (⌘2)")

            Text("\(visible.count)/\(store.folders.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .help("Showing \(visible.count) of \(store.folders.count) folders")

            Button {
                store.openTodaysDailies()
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.borderless)
            .disabled(!store.isDailiesConfigured)
            .help(dailiesHelp)

            Button {
                store.requestNewSag()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("New sag (⌘N)")

            Button {
                store.reload()
                store.selectFirstVisible()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload (⌘R)")
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
                Button("Try Again") {
                    store.reload()
                    store.selectFirstVisible()
                }
            }
        } else if visible.isEmpty {
            ContentUnavailableView.search(text: store.query)
        } else {
            folderList
        }
    }

    private var folderList: some View {
        List(visible, selection: selectedRow) { folder in
            row(folder)
        }
        .listStyle(.inset)
        .focused($listFocused)
        .onKeyPress(.return) {
            store.openSelection()
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
                store.selection = folder.id
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
            store.errorTitle = "Could not open the journal"
            store.errorMessage = error.localizedDescription
        }
    }

    /// "Today's dailies: 2026-10-26.md in ~/…/pkm/dailies"
    private var dailiesHelp: String {
        guard let url = store.todayDailiesURL else {
            return "No dailies folder set — choose one in Settings… (⌘,)"
        }
        return "Open today's dailies (\(url.lastPathComponent)) — ⌘D"
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
}

#Preview {
    ContentView()
        .environment(FolderStore(settings: AppSettings()))
}
