import SwiftUI

struct OnboardingSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var syncId: String = ""
    @State private var password: String = ""

    private var isValid: Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !syncId.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect to Actual Server")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Enter the credentials for your actual-http-api instance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)

            Divider()

            Form {
                Section {
                    TextField("Base URL", text: $baseURL, prompt: Text("https://example.com/v1"))
                        .textContentType(.URL)
                    TextField("API Key", text: $apiKey, prompt: Text("Your API Key"))
                        .textContentType(.password)
                    TextField("Sync ID", text: $syncId, prompt: Text("Your Sync ID"))
                    SecureField("Encryption Password (optional)", text: $password, prompt: Text("Password (if set)"))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button("Use Demo Mode") {
                    appState.isDemoMode = true
                    dismiss()
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Continue") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(20)
        }
        .onAppear {
            baseURL = appState.baseURLString
            apiKey = appState.apiKey
            syncId = appState.syncId
            password = appState.budgetEncryptionPassword
        }
    }

    private func save() {
        appState.baseURLString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.syncId = syncId.trimmingCharacters(in: .whitespacesAndNewlines)
        appState.budgetEncryptionPassword = password
        appState.isDemoMode = false
    }
}
