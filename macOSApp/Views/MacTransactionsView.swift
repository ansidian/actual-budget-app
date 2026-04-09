import SwiftUI

struct MacTransactionsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: TransactionsViewModel?
    @State private var selection: Set<Transaction.ID> = []
    @State private var sortOrder: [KeyPathComparator<Transaction>] = [
        KeyPathComparator(\Transaction.date, order: .reverse)
    ]
    @State private var inspectorState: EditorState = .closed

    private enum EditorState: Equatable {
        case closed
        case adding
        case editing(Transaction)

        var isOpen: Bool { self != .closed }
    }

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    inspectorState = .adding
                } label: {
                    Label("New Transaction", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(vm == nil)

                Button {
                    Task { await vm?.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(vm == nil)
            }
        }
        .searchable(text: searchBinding, placement: .toolbar, prompt: "Search payee, category, notes")
        .task {
            if vm == nil {
                vm = TransactionsViewModel(appState: appState, scope: .all)
                await vm?.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            Task { await vm?.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTransactionRequested)) { _ in
            inspectorState = .adding
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
    private func content(vm: TransactionsViewModel) -> some View {
        let rows = vm.filteredTransactions.sorted(using: sortOrder)
        VStack(spacing: 0) {
            filterBar(vm: vm)
            Divider()
            transactionsTable(vm: vm, rows: rows)
        }
        .inspector(isPresented: Binding(
            get: { inspectorState.isOpen },
            set: { if !$0 { inspectorState = .closed } }
        )) {
            editorPane(vm: vm)
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        }
    }

    @ViewBuilder
    private func filterBar(vm: TransactionsViewModel) -> some View {
        HStack(spacing: 16) {
            Toggle("On-budget only", isOn: Binding(
                get: { vm.onBudgetOnly },
                set: { vm.onBudgetOnly = $0 }
            ))
            .toggleStyle(.switch)

            Picker("Range", selection: Binding(
                get: { vm.filterGranularity },
                set: { vm.filterGranularity = $0 }
            )) {
                ForEach(TransactionsViewModel.Granularity.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            Stepper(value: Binding(
                get: { vm.filterValue },
                set: { vm.filterValue = $0 }
            ), in: 1...365) {
                Text("Last \(vm.filterValue) \(vm.filterGranularity.rawValue)")
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func transactionsTable(vm: TransactionsViewModel, rows: [Transaction]) -> some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { tx in
                Text(tx.date)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Payee") { (tx: Transaction) in
                Text(vm.payeeText(for: tx))
            }
            .width(min: 140, ideal: 200)

            TableColumn("Category") { (tx: Transaction) in
                Text(vm.categoryName(for: tx) ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Account") { (tx: Transaction) in
                Text(vm.accountName(for: tx))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Amount") { (tx: Transaction) in
                MoneyText(amount: tx.amount, currencyCode: appState.currencyCode, signed: true)
            }
            .width(min: 100, ideal: 130)

            TableColumn("Cleared") { (tx: Transaction) in
                Image(systemName: (tx.cleared ?? false) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle((tx.cleared ?? false) ? .green : .secondary)
            }
            .width(60)
        }
        .contextMenu(forSelectionType: Transaction.ID.self) { ids in
            Button("Edit") {
                if let id = ids.first, let tx = rows.first(where: { $0.id == id }) {
                    inspectorState = .editing(tx)
                }
            }
            .disabled(ids.count != 1)

            Button("Delete", role: .destructive) {
                let toDelete = rows.filter { ids.contains($0.id) }
                Task {
                    await vm.deleteMany(toDelete)
                    selection.removeAll()
                }
            }
            .disabled(ids.isEmpty)
        } primaryAction: { ids in
            if let id = ids.first, let tx = rows.first(where: { $0.id == id }) {
                inspectorState = .editing(tx)
            }
        }
        .onDeleteCommand {
            guard !selection.isEmpty else { return }
            let toDelete = rows.filter { selection.contains($0.id) }
            Task {
                await vm.deleteMany(toDelete)
                selection.removeAll()
            }
        }
    }

    @ViewBuilder
    private func editorPane(vm: TransactionsViewModel) -> some View {
        switch inspectorState {
        case .closed:
            EmptyView()
        case .adding:
            MacTransactionEditor(
                transaction: nil,
                initialAccountId: nil,
                accounts: vm.accounts,
                payees: Array(vm.payeesById.values),
                categoriesById: vm.categoriesById,
                onSave: { built in
                    Task {
                        await save(built, vm: vm)
                        inspectorState = .closed
                    }
                },
                onCancel: { inspectorState = .closed }
            )
            .navigationTitle("New Transaction")
        case .editing(let tx):
            MacTransactionEditor(
                transaction: tx,
                initialAccountId: tx.account,
                accounts: vm.accounts,
                payees: Array(vm.payeesById.values),
                categoriesById: vm.categoriesById,
                onSave: { built in
                    Task {
                        await save(built, vm: vm)
                        inspectorState = .closed
                    }
                },
                onCancel: { inspectorState = .closed }
            )
            .navigationTitle("Edit Transaction")
        }
    }

    private func save(_ built: Transaction, vm: TransactionsViewModel) async {
        do {
            let client = try ActualAPIClient(
                baseURLString: appState.baseURLString,
                apiKey: appState.apiKey,
                syncId: appState.syncId,
                budgetEncryptionPassword: appState.budgetEncryptionPassword,
                isDemoMode: appState.isDemoMode
            )
            if let id = built.id {
                try await client.updateTransaction(transactionId: id, transaction: built)
            } else {
                try await client.createTransaction(
                    accountId: built.account,
                    transaction: built,
                    runTransfers: built.transfer_id != nil
                )
            }
            await vm.load()
        } catch {
            AppLogger.shared.log(error: error, context: "MacTransactionsView.save")
            vm.errorMessage = error.localizedDescription
        }
    }
}
