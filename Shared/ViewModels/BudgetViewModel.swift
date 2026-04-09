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
    /// Groups the user has explicitly collapsed in this session. Default state is
    /// expanded, so only the inverse is stored.
    var manuallyCollapsed: Set<String> = []
    var isLoading: Bool = false
    var errorMessage: String?

    // Notes caches. `loaded` set distinguishes "not fetched" from "fetched, empty"
    // so the UI can lazy-load without flickering between states.
    var categoryNotes: [String: String] = [:]
    var categoryNotesLoaded: Set<String> = []
    var monthNotes: [String: String] = [:]  // keyed by monthKey
    var monthNotesLoaded: Set<String> = []

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
        !manuallyCollapsed.contains(groupId)
    }

    func setExpanded(_ groupId: String, _ expanded: Bool) {
        if expanded {
            manuallyCollapsed.remove(groupId)
        } else {
            manuallyCollapsed.insert(groupId)
        }
    }

    func toggleExpansion(_ groupId: String) {
        setExpanded(groupId, !isExpanded(groupId))
    }

    // MARK: - Navigation

    func moveMonth(_ delta: Int) async {
        monthDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: delta, to: monthDate) ?? monthDate
        await load()
    }

    // MARK: - Loading

    func load() async {
        guard appState.isConfigured else { return }
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

    // MARK: - Notes

    func categoryHasNotes(_ id: String) -> Bool {
        !(categoryNotes[id] ?? "").isEmpty
    }

    func categoryNote(_ id: String) -> String {
        categoryNotes[id] ?? ""
    }

    func loadCategoryNotesIfNeeded(_ id: String) async {
        guard !categoryNotesLoaded.contains(id) else { return }
        categoryNotesLoaded.insert(id)
        do {
            let client = try makeClient()
            let text = try await client.fetchCategoryNotes(categoryId: id) ?? ""
            categoryNotes[id] = text
        } catch {
            // Swallow per-entity errors; the indicator just won't light up.
            AppLogger.shared.log(error: error, context: "BudgetViewModel.loadCategoryNotes")
        }
    }

    func saveCategoryNotes(_ id: String, text: String) async {
        do {
            let client = try makeClient()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try await client.deleteCategoryNotes(categoryId: id)
                categoryNotes[id] = ""
            } else {
                try await client.setCategoryNotes(categoryId: id, text: text)
                categoryNotes[id] = text
            }
            categoryNotesLoaded.insert(id)
        } catch {
            AppLogger.shared.log(error: error, context: "BudgetViewModel.saveCategoryNotes")
            self.errorMessage = error.localizedDescription
        }
    }

    func currentMonthNote() -> String {
        monthNotes[monthKey] ?? ""
    }

    func loadCurrentMonthNoteIfNeeded() async {
        let key = monthKey
        guard !monthNotesLoaded.contains(key) else { return }
        monthNotesLoaded.insert(key)
        do {
            let client = try makeClient()
            let text = try await client.fetchBudgetMonthNotes(month: key) ?? ""
            monthNotes[key] = text
        } catch {
            AppLogger.shared.log(error: error, context: "BudgetViewModel.loadMonthNote")
        }
    }

    func saveCurrentMonthNote(_ text: String) async {
        let key = monthKey
        do {
            let client = try makeClient()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try await client.deleteBudgetMonthNotes(month: key)
                monthNotes[key] = ""
            } else {
                try await client.setBudgetMonthNotes(month: key, text: text)
                monthNotes[key] = text
            }
            monthNotesLoaded.insert(key)
        } catch {
            AppLogger.shared.log(error: error, context: "BudgetViewModel.saveMonthNote")
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
