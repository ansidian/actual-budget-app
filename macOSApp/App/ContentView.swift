import SwiftUI

enum SidebarSection: String, Identifiable, Hashable, CaseIterable {
    case dashboard, accounts, budget, transactions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .accounts: return "Accounts"
        case .budget: return "Budget"
        case .transactions: return "Transactions"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .accounts: return "creditcard"
        case .budget: return "chart.pie"
        case .transactions: return "list.bullet.rectangle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @SceneStorage("selectedSidebarSection") private var selectedRaw: String = SidebarSection.dashboard.rawValue
    @State private var showingOnboarding: Bool = false

    private var selected: Binding<SidebarSection?> {
        Binding(
            get: { SidebarSection(rawValue: selectedRaw) ?? .dashboard },
            set: { selectedRaw = ($0 ?? .dashboard).rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: selected) { section in
                NavigationLink(value: section) {
                    Label(section.label, systemImage: section.systemImage)
                }
            }
            .navigationTitle("Actual Budget")
            .frame(minWidth: 180)
        } detail: {
            NavigationStack {
                Group {
                    switch selected.wrappedValue ?? .dashboard {
                    case .dashboard:
                        MacDashboardView()
                    case .accounts:
                        MacAccountsView()
                    case .budget:
                        MacBudgetView()
                    case .transactions:
                        MacTransactionsView()
                    }
                }
                .frame(minWidth: 700, minHeight: 480)
            }
        }
        .onAppear {
            if !appState.isConfigured {
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchSidebarSection)) { note in
            if let raw = note.object as? String, SidebarSection(rawValue: raw) != nil {
                selectedRaw = raw
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingSheet()
                .environmentObject(appState)
                .frame(width: 520, height: 480)
        }
    }
}

