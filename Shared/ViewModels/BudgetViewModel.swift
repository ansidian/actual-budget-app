import Foundation
import Observation

/// Drives the budget month view: header totals, category groups, month navigation,
/// and group expansion state.
@MainActor
@Observable
final class BudgetViewModel {
    private let appState: AppState

    var monthDate: Date = Date()
    var budget: BudgetMonth?
    var monthGroups: [BudgetMonthCategoryGroup] = []
    var expandedGroups: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Derived

    var sortedGroups: [BudgetMonthCategoryGroup] {
        let income = monthGroups.filter { $0.is_income == true }
        let spend = monthGroups.filter { $0.is_income != true }
        return spend + income
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthDate)
    }

    var monthKey: String {
        let cal = Calendar.current
        return String(format: "%04d-%02d", cal.component(.year, from: monthDate), cal.component(.month, from: monthDate))
    }

    func isExpanded(_ groupId: String) -> Bool {
        expandedGroups.contains(groupId)
    }

    func toggleExpansion(_ groupId: String) {
        if expandedGroups.contains(groupId) {
            expandedGroups.remove(groupId)
        } else {
            expandedGroups.insert(groupId)
        }
    }

    // MARK: - Navigation

    func moveMonth(_ delta: Int) async {
        monthDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: delta, to: monthDate) ?? monthDate
        await load()
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            let key = monthKey
            async let bm = client.fetchBudgetMonth(key)
            async let groups = client.fetchBudgetMonthCategoryGroups(key)
            let (budgetMonth, groupList) = try await (bm, groups)
            self.budget = budgetMonth
            self.monthGroups = groupList
        } catch {
            AppLogger.shared.log(error: error, context: "BudgetViewModel.load")
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
}
