import Foundation
import Observation

/// Manages the list of accounts plus per-account balances. Handles search filtering,
/// soft/hard reload semantics, and account creation/close/reopen.
@MainActor
@Observable
final class AccountsViewModel {
    private let appState: AppState

    var accounts: [Account] = []
    var balancesById: [String: Int] = [:]
    var search: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    var accountNotes: [String: String] = [:]
    var accountNotesLoaded: Set<String> = []

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Derived

    var onBudget: [Account] { filtered(accounts.filter { !$0.offbudget }) }
    var offBudget: [Account] { filtered(accounts.filter { $0.offbudget }) }

    func balance(for account: Account) -> Int? {
        balancesById[account.id]
    }

    func totalBalance() -> Int {
        accounts.map { balancesById[$0.id] ?? 0 }.reduce(0, +)
    }

    func total(for accounts: [Account]) -> Int {
        accounts.map { balancesById[$0.id] ?? 0 }.reduce(0, +)
    }

    // MARK: - Loading

    func softReload() async { await load(clearBalances: false) }
    func hardReload() async { await load(clearBalances: true) }

    private func load(clearBalances: Bool) async {
        guard appState.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            let list = try await client.fetchAccounts()
            self.accounts = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if clearBalances { self.balancesById.removeAll() }

            await withTaskGroup(of: (String, Int?).self) { group in
                for acc in list {
                    let id = acc.id
                    if balancesById[id] != nil { continue }
                    group.addTask { [client] in
                        let bal = try? await client.fetchAccountBalance(accountId: id)
                        return (id, bal)
                    }
                }
                for await (id, bal) in group {
                    if let bal { self.balancesById[id] = bal }
                }
            }
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.load")
            self.errorMessage = error.localizedDescription
        }
    }

    func loadBalanceIfNeeded(_ account: Account) async {
        if balancesById[account.id] != nil { return }
        do {
            let client = try makeClient()
            let bal = try await client.fetchAccountBalance(accountId: account.id)
            self.balancesById[account.id] = bal
        } catch {
            // ignore per-row errors
        }
    }

    // MARK: - Mutations

    func createAccount(name: String, offbudget: Bool) async {
        do {
            let client = try makeClient()
            _ = try await client.createAccount(name: name, offbudget: offbudget)
            await hardReload()
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.createAccount")
            self.errorMessage = error.localizedDescription
        }
    }

    func closeAccount(_ account: Account, transferAccountId: String?, transferCategoryId: String?) async {
        do {
            let client = try makeClient()
            try await client.closeAccount(accountId: account.id, transferAccountId: transferAccountId, transferCategoryId: transferCategoryId)
            await hardReload()
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.closeAccount")
            self.errorMessage = error.localizedDescription
        }
    }

    func reopenAccount(_ account: Account) async {
        do {
            let client = try makeClient()
            try await client.reopenAccount(accountId: account.id)
            await hardReload()
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.reopenAccount")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Notes

    func accountHasNotes(_ id: String) -> Bool {
        !(accountNotes[id] ?? "").isEmpty
    }

    func accountNote(_ id: String) -> String {
        accountNotes[id] ?? ""
    }

    func loadAccountNotesIfNeeded(_ id: String) async {
        guard !accountNotesLoaded.contains(id) else { return }
        accountNotesLoaded.insert(id)
        do {
            let client = try makeClient()
            let text = try await client.fetchAccountNotes(accountId: id) ?? ""
            accountNotes[id] = text
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.loadAccountNotes")
        }
    }

    func saveAccountNotes(_ id: String, text: String) async {
        do {
            let client = try makeClient()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try await client.deleteAccountNotes(accountId: id)
                accountNotes[id] = ""
            } else {
                try await client.setAccountNotes(accountId: id, text: text)
                accountNotes[id] = text
            }
            accountNotesLoaded.insert(id)
        } catch {
            AppLogger.shared.log(error: error, context: "AccountsViewModel.saveAccountNotes")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func filtered(_ list: [Account]) -> [Account] {
        guard !search.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(search) }
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
