import SwiftUI

struct MacAccountsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: AccountsViewModel?
    @State private var showingCreate: Bool = false
    @State private var sortOrder: [KeyPathComparator<Account>] = [
        KeyPathComparator(\Account.name)
    ]
    @State private var selection: Account.ID?

    var body: some View {
        Group {
            if let vm {
                accountsTable(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingCreate = true
                } label: {
                    Label("New Account", systemImage: "plus")
                }
                .disabled(vm == nil)

                Button {
                    Task { await vm?.hardReload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(vm == nil)
            }
        }
        .searchable(text: searchBinding, placement: .toolbar, prompt: "Search accounts")
        .task {
            if vm == nil {
                vm = AccountsViewModel(appState: appState)
                await vm?.softReload()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            Task { await vm?.hardReload() }
        }
        .sheet(isPresented: $showingCreate) {
            CreateAccountSheet { name, offbudget in
                Task { await vm?.createAccount(name: name, offbudget: offbudget) }
            }
            .frame(width: 360, height: 200)
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { vm?.errorMessage = nil }
        } message: {
            Text(vm?.errorMessage ?? "")
        }
    }

    private var searchBinding: Binding<String> {
        Binding(get: { vm?.search ?? "" }, set: { vm?.search = $0 })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm?.errorMessage != nil },
            set: { if !$0 { vm?.errorMessage = nil } }
        )
    }

    @ViewBuilder
    private func accountsTable(vm: AccountsViewModel) -> some View {
        let allAccounts = (vm.onBudget + vm.offBudget).sorted(using: sortOrder)
        VStack(spacing: 0) {
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                MoneyText(amount: vm.totalBalance(), currencyCode: appState.currencyCode, emphasis: true)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.background.secondary)

            Divider()

            Table(allAccounts, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { acc in
                    HStack {
                        Image(systemName: acc.offbudget ? "tray" : "creditcard.fill")
                            .foregroundStyle(.secondary)
                        Text(acc.name)
                    }
                }
                TableColumn("Type") { (acc: Account) in
                    Text(acc.offbudget ? "Off-Budget" : "On-Budget")
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 120)
                TableColumn("Status") { (acc: Account) in
                    Text(acc.closed ? "Closed" : "Active")
                        .foregroundStyle(acc.closed ? .orange : .secondary)
                }
                .width(min: 80, ideal: 100)
                TableColumn("Balance") { (acc: Account) in
                    MoneyText(amount: vm.balance(for: acc) ?? 0, currencyCode: appState.currencyCode)
                }
                .width(min: 100, ideal: 130)
            }
        }
    }
}

private struct CreateAccountSheet: View {
    var onCreate: (String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var offbudget: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Account")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Divider()

            Form {
                TextField("Name", text: $name)
                Toggle("Off-budget account", isOn: $offbudget)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Spacer(minLength: 0)
            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    onCreate(name, offbudget)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding(12)
        }
    }
}
