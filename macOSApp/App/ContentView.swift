import SwiftUI

enum SidebarSection: String, Identifiable, Hashable, CaseIterable {
    case dashboard, accounts, budget, transactions, schedules

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .accounts: return "Accounts"
        case .budget: return "Budget"
        case .transactions: return "Transactions"
        case .schedules: return "Schedules"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .accounts: return "creditcard"
        case .budget: return "chart.pie"
        case .transactions: return "list.bullet.rectangle"
        case .schedules: return "calendar.badge.clock"
        }
    }
}

/// Broader sidebar selection model: either a top-level section or a specific account
/// under the Accounts group.
enum SidebarSelection: Hashable {
    case section(SidebarSection)
    case account(String)

    var storageKey: String {
        switch self {
        case .section(let s): return s.rawValue
        case .account(let id): return "account:\(id)"
        }
    }

    init(storageKey: String) {
        if storageKey.hasPrefix("account:") {
            self = .account(String(storageKey.dropFirst("account:".count)))
        } else if let section = SidebarSection(rawValue: storageKey) {
            self = .section(section)
        } else {
            self = .section(.dashboard)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var accountsVM: AccountsViewModel?
    @SceneStorage("selectedSidebarSelection") private var selectedRaw: String = SidebarSection.dashboard.rawValue
    @State private var showingOnboarding: Bool = false

    private var selection: Binding<SidebarSelection?> {
        Binding(
            get: { SidebarSelection(storageKey: selectedRaw) },
            set: { selectedRaw = ($0 ?? .section(.dashboard)).storageKey }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Actual Budget")
                .frame(minWidth: 200)
        } detail: {
            NavigationStack {
                detail
                    .frame(minWidth: 700, minHeight: 480)
            }
        }
        .task {
            if accountsVM == nil {
                let vm = AccountsViewModel(appState: appState)
                accountsVM = vm
                await vm.softReload()
            }
        }
        .onAppear {
            if !appState.isConfigured {
                showingOnboarding = true
            }
        }
        .onChange(of: appState.isConfigured) { _, configured in
            if !configured && !showingOnboarding {
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

    @ViewBuilder
    private var sidebar: some View {
        List(selection: selection) {
            Section {
                ForEach(SidebarSection.allCases) { section in
                    NavigationLink(value: SidebarSelection.section(section)) {
                        Label(section.label, systemImage: section.systemImage)
                    }
                }
            }

            if let accounts = accountsVM?.accounts, !accounts.isEmpty {
                Section("Accounts") {
                    ForEach(accounts, id: \.id) { acc in
                        NavigationLink(value: SidebarSelection.account(acc.id)) {
                            Label {
                                Text(acc.name)
                            } icon: {
                                Image(systemName: acc.offbudget ? "tray" : "creditcard.fill")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection.wrappedValue ?? .section(.dashboard) {
        case .section(.dashboard):
            MacDashboardView()
        case .section(.accounts):
            if let vm = accountsVM {
                MacAccountsView(vm: vm)
            } else {
                ProgressView()
            }
        case .section(.budget):
            MacBudgetView()
        case .section(.transactions):
            MacTransactionsView(accountFilter: nil)
                .id("all")
        case .section(.schedules):
            MacSchedulesView()
        case .account(let id):
            if let account = accountsVM?.accounts.first(where: { $0.id == id }) {
                MacTransactionsView(accountFilter: account)
                    .id("account:\(id)")
            } else {
                ProgressView()
            }
        }
    }
}
