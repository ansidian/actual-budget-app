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
            Group {
                switch selected.wrappedValue ?? .dashboard {
                case .dashboard:
                    PlaceholderView(title: "Dashboard")
                case .accounts:
                    PlaceholderView(title: "Accounts")
                case .budget:
                    PlaceholderView(title: "Budget")
                case .transactions:
                    PlaceholderView(title: "Transactions")
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .onAppear {
            if !appState.isConfigured {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingSheet()
                .environmentObject(appState)
                .frame(width: 520, height: 480)
        }
    }
}

private struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("\(title) — coming soon")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
    }
}
