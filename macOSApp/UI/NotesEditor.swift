import SwiftUI

/// Popover-style editor: used inside `.popover` for category/account notes.
/// Owns its own draft text via a binding passed in from the parent so the
/// parent can prefill / react to changes.
struct NotesEditor: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
    }
}

/// Sheet-style notes editor with an internal draft. Used for larger notes
/// surfaces (e.g. budget-month notes) that aren't tied to a row.
struct NotesEditorSheet: View {
    let title: String
    let initialText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(16)

            Divider()

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .padding(12)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onAppear { draft = initialText }
    }
}
