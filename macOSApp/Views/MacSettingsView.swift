import SwiftUI

struct MacSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            ConnectionTab()
                .tabItem { Label("Connection", systemImage: "network") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "gearshape.2") }
        }
        .frame(width: 520, height: 360)
    }
}

private struct ConnectionTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var syncId: String = ""
    @State private var password: String = ""

    var body: some View {
        Form {
            Section {
                TextField("Base URL", text: $baseURL)
                TextField("API Key", text: $apiKey)
                TextField("Sync ID", text: $syncId)
                SecureField("Encryption Password", text: $password)
            }
            Section {
                Button("Save") { save() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            baseURL = appState.baseURLString
            apiKey = appState.apiKey
            syncId = appState.syncId
            password = appState.budgetEncryptionPassword
        }
    }

    private func save() {
        appState.baseURLString = baseURL
        appState.apiKey = apiKey
        appState.syncId = syncId
        appState.budgetEncryptionPassword = password
    }
}

private struct AppearanceTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Picker("Currency", selection: $appState.currencyCode) {
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
                Text("JPY (¥)").tag("JPY")
                Text("CAD (C$)").tag("CAD")
                Text("AUD (A$)").tag("AUD")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AdvancedTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Toggle("Demo Mode", isOn: $appState.isDemoMode)
            Section {
                Button("Reset Configuration", role: .destructive) {
                    appState.resetConfiguration()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
