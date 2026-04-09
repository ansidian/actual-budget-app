import SwiftUI

@main
struct ActualBudgetMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Transaction") {
                    NotificationCenter.default.post(name: .newTransactionRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .refreshRequested, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandMenu("Go") {
                Button("Dashboard") {
                    NotificationCenter.default.post(
                        name: .switchSidebarSection,
                        object: SidebarSection.dashboard.rawValue
                    )
                }
                .keyboardShortcut("1", modifiers: [.command])
                Button("Accounts") {
                    NotificationCenter.default.post(
                        name: .switchSidebarSection,
                        object: SidebarSection.accounts.rawValue
                    )
                }
                .keyboardShortcut("2", modifiers: [.command])
                Button("Budget") {
                    NotificationCenter.default.post(
                        name: .switchSidebarSection,
                        object: SidebarSection.budget.rawValue
                    )
                }
                .keyboardShortcut("3", modifiers: [.command])
                Button("Transactions") {
                    NotificationCenter.default.post(
                        name: .switchSidebarSection,
                        object: SidebarSection.transactions.rawValue
                    )
                }
                .keyboardShortcut("4", modifiers: [.command])
            }
        }

        Settings {
            MacSettingsView()
                .environmentObject(appState)
        }
    }
}

extension Notification.Name {
    static let newTransactionRequested = Notification.Name("ActualBudgetMac.newTransactionRequested")
    static let refreshRequested = Notification.Name("ActualBudgetMac.refreshRequested")
    static let switchSidebarSection = Notification.Name("ActualBudgetMac.switchSidebarSection")
}
