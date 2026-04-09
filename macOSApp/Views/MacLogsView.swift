import SwiftUI
import UniformTypeIdentifiers

struct MacLogsView: View {
    @State private var logText: String = ""
    @State private var isExporting: Bool = false
    @State private var exportDocument: LogDocument?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Application Logs")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    exportDocument = LogDocument(text: logText)
                    isExporting = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(logText.isEmpty)
                Button(role: .destructive) {
                    AppLogger.shared.clear()
                    refresh()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
            .padding(16)

            Divider()

            ScrollView {
                Text(logText.isEmpty ? "No log entries." : logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.background.secondary)
        }
        .onAppear { refresh() }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "actual-budget.log"
        ) { _ in }
    }

    private func refresh() {
        logText = AppLogger.shared.readLogText()
    }
}

private struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents, let s = String(data: data, encoding: .utf8) {
            self.text = s
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
