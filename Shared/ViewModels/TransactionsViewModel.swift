import Foundation
import Observation

/// Backs both the per-account and all-transactions views. Owns transaction fetching,
/// filtering, and CRUD. Holds account/payee/category lookup tables for display.
@MainActor
@Observable
final class TransactionsViewModel {
    enum Granularity: String, CaseIterable, Identifiable {
        case day = "Days"
        case week = "Weeks"
        case month = "Months"
        case year = "Years"
        var id: String { rawValue }
    }

    enum Scope: Equatable {
        /// Fetch transactions for a single account.
        case account(Account)
        /// Fetch transactions across all accounts.
        case all
    }

    private let appState: AppState

    var scope: Scope
    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var categoriesById: [String: String] = [:]
    var payeesById: [String: Payee] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    // Filter state (used by the all-transactions view)
    var onBudgetOnly: Bool = true
    var filterGranularity: Granularity = .day
    var filterValue: Int = 30
    var search: String = ""

    init(appState: AppState, scope: Scope = .all) {
        self.appState = appState
        self.scope = scope
    }

    // MARK: - Derived

    var filteredTransactions: [Transaction] {
        let onBudgetIds = Set(accounts.filter { !$0.offbudget }.map { $0.id })
        let allIds = Set(accounts.map { $0.id })
        let target = onBudgetOnly ? onBudgetIds : allIds
        let since = sinceDateString()

        return transactions
            .filter { target.contains($0.account) }
            .filter { $0.date >= since }
            .filter { !isTransferToOnBudget($0) }
            .filter(matchesSearch)
            .sorted { $0.date > $1.date }
    }

    func payeeText(for tx: Transaction) -> String {
        if let dest = transferDestinationAccount(tx) {
            return "Transfer \((tx.amount ?? 0) < 0 ? "to" : "from"): \(dest.name)"
        }
        if let payeeId = tx.payee, let p = payeesById[payeeId] { return p.name }
        if let n = tx.payee_name, !n.isEmpty { return n }
        return "(No payee)"
    }

    func categoryName(for tx: Transaction) -> String? {
        guard let id = tx.category else { return nil }
        return categoriesById[id]
    }

    func accountName(for tx: Transaction) -> String {
        accounts.first { $0.id == tx.account }?.name ?? "Unknown"
    }

    // MARK: - Loading

    func load() async {
        guard appState.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            async let accs = client.fetchAccounts()
            async let cats = client.fetchCategories()
            async let payees = client.fetchPayees()
            let (accountList, categories, payeesList) = try await (accs, cats, payees)

            let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            let payeeMap = Dictionary(uniqueKeysWithValues: payeesList.map { ($0.id, $0) })

            let txs: [Transaction]
            switch scope {
            case .account(let account):
                txs = try await client.fetchTransactions(accountId: account.id, since: defaultSinceDate())
            case .all:
                let since = sinceDateString()
                let perAccount = try await withThrowingTaskGroup(of: [Transaction].self) { group -> [[Transaction]] in
                    for acc in accountList {
                        let id = acc.id
                        group.addTask { try await client.fetchTransactions(accountId: id, since: since) }
                    }
                    var results: [[Transaction]] = []
                    for try await list in group { results.append(list) }
                    return results
                }
                txs = perAccount.flatMap { $0 }
            }

            self.accounts = accountList
            self.categoriesById = catMap
            self.payeesById = payeeMap
            self.transactions = txs
        } catch {
            AppLogger.shared.log(error: error, context: "TransactionsViewModel.load")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    func delete(_ tx: Transaction) async {
        guard let id = tx.id else { return }
        transactions.removeAll { $0.id == id }
        do {
            let client = try makeClient()
            try await client.deleteTransaction(transactionId: id)
        } catch {
            AppLogger.shared.log(error: error, context: "TransactionsViewModel.delete")
            self.errorMessage = error.localizedDescription
        }
    }

    func deleteMany(_ txs: [Transaction]) async {
        for tx in txs { await delete(tx) }
    }

    // MARK: - Helpers

    private func matchesSearch(_ tx: Transaction) -> Bool {
        guard !search.isEmpty else { return true }
        let needle = search.lowercased()
        if payeeText(for: tx).lowercased().contains(needle) { return true }
        if let cat = categoryName(for: tx)?.lowercased(), cat.contains(needle) { return true }
        if let notes = tx.notes?.lowercased(), notes.contains(needle) { return true }
        return false
    }

    private func transferDestinationAccount(_ tx: Transaction) -> Account? {
        if let payeeId = tx.payee,
           let p = payeesById[payeeId],
           let destAcctId = p.transfer_acct {
            return accounts.first { $0.id == destAcctId }
        }
        return nil
    }

    private func isTransferToOnBudget(_ tx: Transaction) -> Bool {
        if let dest = transferDestinationAccount(tx) {
            return !dest.offbudget
        }
        return false
    }

    private func sinceDateString() -> String {
        let cal = Calendar.current
        let now = Date()
        let fromDate: Date
        switch filterGranularity {
        case .day:   fromDate = cal.date(byAdding: .day, value: -filterValue, to: now) ?? now
        case .week:  fromDate = cal.date(byAdding: .weekOfYear, value: -filterValue, to: now) ?? now
        case .month: fromDate = cal.date(byAdding: .month, value: -filterValue, to: now) ?? now
        case .year:  fromDate = cal.date(byAdding: .year, value: -filterValue, to: now) ?? now
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: fromDate)
    }

    private func defaultSinceDate() -> String {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let f = DateFormatter()
        f.calendar = cal
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    private func makeClient() throws -> ActualAPIClient {
        try ActualAPIClient(
            baseURLString: appState.baseURLString,
            apiKey: appState.apiKey,
            syncId: appState.syncId,
            budgetEncryptionPassword: appState.budgetEncryptionPassword,
            isDemoMode: appState.isDemoMode
        )
    }
}
