import Foundation
import Observation

/// Aggregates accounts, categories, payees, and recent transactions to drive the
/// Dashboard view. Owns the spending calculations that were previously inlined in
/// the iOS DashboardView.
@MainActor
@Observable
final class DashboardViewModel {
    private let appState: AppState

    var accounts: [Account] = []
    var transactions: [Transaction] = []
    var categoriesById: [String: String] = [:]
    var payeesById: [String: Payee] = [:]
    var isLoading: Bool = false
    var errorMessage: String?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Derived state

    var onBudgetAccounts: [Account] {
        accounts.filter { !$0.offbudget }
    }

    var recentNonTransferOnBudget: [Transaction] {
        let onBudgetIds = Set(onBudgetAccounts.map { $0.id })
        return transactions
            .filter { onBudgetIds.contains($0.account) && !isTransfer($0) }
            .sorted { $0.date > $1.date }
    }

    var recentFive: [Transaction] {
        Array(recentNonTransferOnBudget.prefix(5))
    }

    func spentToday() -> Int {
        let today = Self.formatDate(Date())
        let onBudgetIds = Set(onBudgetAccounts.map { $0.id })
        let todays = transactions.filter { $0.date == today && onBudgetIds.contains($0.account) && !isTransfer($0) }
        return -todays.compactMap { $0.amount }.filter { $0 < 0 }.reduce(0, +)
    }

    func spentThisMonth() -> Int {
        let (start, end) = Self.monthRange(date: Date())
        let onBudgetIds = Set(onBudgetAccounts.map { $0.id })
        let list = transactions.filter { $0.date >= start && $0.date <= end && onBudgetIds.contains($0.account) && !isTransfer($0) }
        return -list.compactMap { $0.amount }.filter { $0 < 0 }.reduce(0, +)
    }

    func spentLastMonth() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let (start, end) = Self.monthRange(date: lastMonthDate)
        let onBudgetIds = Set(onBudgetAccounts.map { $0.id })
        let list = transactions.filter { $0.date >= start && $0.date <= end && onBudgetIds.contains($0.account) && !isTransfer($0) }
        return -list.compactMap { $0.amount }.filter { $0 < 0 }.reduce(0, +)
    }

    func payeeName(for tx: Transaction) -> String {
        if let payeeId = tx.payee, let p = payeesById[payeeId] { return p.name }
        if let n = tx.payee_name, !n.isEmpty { return n }
        return "(No payee)"
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
            let (accList, catList, payeeList) = try await (accs, cats, payees)

            let since = Self.firstOfThisMonthMinus(days: 31)
            let txs = try await withThrowingTaskGroup(of: [Transaction].self) { group -> [[Transaction]] in
                for acc in accList {
                    let id = acc.id
                    group.addTask { try await client.fetchTransactions(accountId: id, since: since) }
                }
                var results: [[Transaction]] = []
                for try await list in group { results.append(list) }
                return results
            }

            self.accounts = accList
            self.categoriesById = Dictionary(uniqueKeysWithValues: catList.map { ($0.id, $0.name) })
            self.payeesById = Dictionary(uniqueKeysWithValues: payeeList.map { ($0.id, $0) })
            self.transactions = txs.flatMap { $0 }
        } catch {
            AppLogger.shared.log(error: error, context: "DashboardViewModel.load")
            self.errorMessage = error.localizedDescription
        }
    }

    func delete(_ tx: Transaction) async {
        guard let txId = tx.id else { return }
        // Optimistic removal
        transactions.removeAll { $0.id == txId }
        do {
            let client = try makeClient()
            try await client.deleteTransaction(transactionId: txId)
        } catch {
            AppLogger.shared.log(error: error, context: "DashboardViewModel.delete")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func makeClient() throws -> ActualAPIClient {
        try ActualAPIClient(
            baseURLString: appState.baseURLString,
            apiKey: appState.apiKey,
            syncId: appState.syncId,
            budgetEncryptionPassword: appState.budgetEncryptionPassword,
            isDemoMode: appState.isDemoMode
        )
    }

    private func isTransfer(_ tx: Transaction) -> Bool {
        if tx.transfer_id != nil { return true }
        if let payeeId = tx.payee, let p = payeesById[payeeId], p.transfer_acct != nil { return true }
        return false
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func monthRange(date: Date) -> (String, String) {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: date)
        let startDate = cal.date(from: comps) ?? date
        let endDate = cal.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? date
        return (formatDate(startDate), formatDate(endDate))
    }

    private static func firstOfThisMonthMinus(days: Int) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: Date())
        let start = cal.date(from: comps) ?? Date()
        let since = cal.date(byAdding: .day, value: -days, to: start) ?? start
        return formatDate(since)
    }
}
