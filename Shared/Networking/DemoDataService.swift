import Foundation

class DemoDataService {
    static let shared = DemoDataService()
    private init() {}
    
    private let accountNames = ["Checking", "Savings", "Credit Card", "Mortgage"]
    private let payeeNames = ["Grocery Store", "Gas Station", "Electric Company", "Paycheck", "Coffee Shop", "Amazon", "Netflix"]
    private let categoryNames = ["Groceries", "Transportation", "Utilities", "Income", "Restaurants", "Shopping", "Entertainment"]
    
    func generateAccounts() -> [Account] {
        return accountNames.indices.map {
            Account(id: "acc_\($0)", name: accountNames[$0], offbudget: $0 > 2, closed: false)
        }
    }
    
    func generateCategories() -> [Category] {
        return categoryNames.indices.map {
            Category(id: "cat_\($0)", name: categoryNames[$0], is_income: categoryNames[$0] == "Income", hidden: false, group_id: "group_\($0 % 2)")
        }
    }
    
    func generatePayees() -> [Payee] {
        return payeeNames.indices.map {
            Payee(id: "payee_\($0)", name: payeeNames[$0], category: nil, transfer_acct: nil)
        }
    }
    
    func generateTransactions(for accountId: String, since: String) -> [Transaction] {
        var transactions: [Transaction] = []
        for i in 0..<30 {
            let isExpense = Double.random(in: 0...1) > 0.2
            let amount = Int.random(in: 500...15000) * (isExpense ? -1 : 1)
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; let dateString = f.string(from: date)
            
            let transaction = Transaction(
                id: "tx_\(accountId)_\(i)",
                account: accountId,
                date: dateString,
                amount: amount,
                payee: "payee_\(Int.random(in: 0..<payeeNames.count))",
                payee_name: nil, imported_payee: nil,
                category: "cat_\(Int.random(in: 0..<categoryNames.count))",
                notes: nil, imported_id: nil, transfer_id: nil, cleared: true, subtransactions: nil
            )
            transactions.append(transaction)
        }
        return transactions
    }
    
    func demoSinceDateString(daysBack: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func generateBudgetMonth() -> BudgetMonth {
        BudgetMonth(
            month: "2025-10",
            incomeAvailable: 250000,
            lastMonthOverspent: 15000,
            forNextMonth: 50000,
            totalBudgeted: 300000,
            toBudget: 12345,
            fromLastMonth: 100000,
            totalIncome: 400000,
            totalSpent: -280000,
            totalBalance: 120000
        )
    }
    
    /// Fake notes for demo mode. Keyed by path so we can serve category /
    /// account / budget-month notes without parsing the URL structure.
    func demoNote(for path: String) -> String? {
        if path.contains("/notes/category/cat_0") { return "#template $500 monthly\nMain grocery budget for the household." }
        if path.contains("/notes/category/cat_2") { return "Covers electric, water, internet." }
        if path.contains("/notes/account/acc_0") { return "Primary checking — used for bills." }
        if path.contains("/notes/budgetmonth/") { return "Demo month notes." }
        return nil
    }

    func generateSchedules() -> [Schedule] {
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        let start = today.string(from: Date())

        // Fixed rent — monthly recurring, exact amount
        let rent = Schedule(
            id: "sch_rent",
            name: "Rent",
            rule: nil,
            next_date: start,
            completed: false,
            posts_transaction: true,
            payee: "payee_0",
            account: "acc_0",
            amount: .exact(-150000),
            amountOp: .is,
            date: .recurring(RecurConfig(
                frequency: .monthly,
                interval: 1,
                skipWeekend: nil,
                start: start,
                endMode: .never,
                endOccurrences: nil,
                endDate: nil,
                weekendSolveMode: nil
            ))
        )

        // Approximate groceries — monthly, approximate amount
        let groceries = Schedule(
            id: "sch_groceries",
            name: "Groceries",
            rule: nil,
            next_date: start,
            completed: false,
            posts_transaction: false,
            payee: "payee_0",
            account: "acc_0",
            amount: .exact(-40000),
            amountOp: .isapprox,
            date: .recurring(RecurConfig(
                frequency: .weekly,
                interval: 1,
                skipWeekend: nil,
                start: start,
                endMode: .never,
                endOccurrences: nil,
                endDate: nil,
                weekendSolveMode: nil
            ))
        )

        // Utility — range, one-off
        let utility = Schedule(
            id: "sch_utility",
            name: "Utilities",
            rule: nil,
            next_date: start,
            completed: false,
            posts_transaction: false,
            payee: "payee_2",
            account: "acc_0",
            amount: .range(-12000, -18000),
            amountOp: .isbetween,
            date: .once(start)
        )

        return [rent, groceries, utility]
    }

    func generateBudgetCategoryGroups() -> [BudgetMonthCategoryGroup] {
        let group1 = BudgetMonthCategoryGroup(id: "group_0", name: "Frequent", is_income: false, hidden: false, categories: [
            BudgetMonthCategory(id: "cat_0", name: "Groceries", is_income: false, hidden: false, group_id: "group_0", budgeted: 50000, spent: -45000, balance: 5000, carryover: false, received: nil),
            BudgetMonthCategory(id: "cat_1", name: "Transportation", is_income: false, hidden: false, group_id: "group_0", budgeted: 20000, spent: -22000, balance: -2000, carryover: false, received: nil)
        ], budgeted: 70000, spent: -67000, balance: 3000)

        let group2 = BudgetMonthCategoryGroup(id: "group_1", name: "Bills", is_income: false, hidden: false, categories: [
            BudgetMonthCategory(id: "cat_2", name: "Utilities", is_income: false, hidden: false, group_id: "group_1", budgeted: 15000, spent: -14500, balance: 500, carryover: false, received: nil)
        ], budgeted: 15000, spent: -14500, balance: 500)

        let incomeGroup = BudgetMonthCategoryGroup(id: "group_income", name: "Income", is_income: true, hidden: false, categories: [
            BudgetMonthCategory(id: "cat_3", name: "Paycheck", is_income: true, hidden: false, group_id: "group_income", budgeted: 0, spent: nil, balance: 400000, carryover: false, received: 400000)
        ], budgeted: 0, spent: 400000, balance: 400000)
        
        return [group1, group2, incomeGroup]
    }
}