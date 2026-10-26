import SwiftUI

/// Sheet for creating a new case: shows the number that will be used and asks
/// for the description that becomes part of the folder name.
struct NewSagSheet: View {
    let root: URL
    let number: Int
    let template: String
    var onCreate: (FolderItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var errorMessage: String?
    @FocusState private var descriptionFocused: Bool

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewName: String {
        NewSag.folderName(
            number: number,
            description: trimmedDescription.isEmpty ? "…" : trimmedDescription
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New sag")
                .font(.headline)

            HStack(spacing: 8) {
                Text("Number")
                    .foregroundStyle(.secondary)
                Text(NewSag.formatted(number))
                    .monospacedDigit()
                Spacer()
                Text(Journal.fileName(forFolderNamed: previewName) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Description", text: $description)
                .textFieldStyle(.roundedBorder)
                .focused($descriptionFocused)
                .onSubmit(create)

            Text(previewName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedDescription.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { descriptionFocused = true }
    }

    private func create() {
        do {
            let folder = try NewSag.create(
                description: description,
                in: root,
                number: number,
                template: template
            )
            onCreate(folder)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NewSagSheet(
        root: FolderScanner.defaultRoot,
        number: 79,
        template: Journal.defaultTemplate,
        onCreate: { _ in }
    )
}
