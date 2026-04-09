import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

struct GeneralResponseMessage: Decodable {
    let message: String
}

struct Account: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var offbudget: Bool
    var closed: Bool
}

struct AccountsListResponse: Decodable {
    let data: [Account]
}

struct Category: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let is_income: Bool?
    let hidden: Bool?
    let group_id: String?
}

struct CategoriesListResponse: Decodable {
    let data: [Category]
}

struct Payee: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: String?
    let transfer_acct: String?
}

struct PayeesListResponse: Decodable {
    let data: [Payee]
}

struct Transaction: Identifiable, Codable, Equatable {
    let id: String?
    let account: String
    let date: String
    let amount: Int?
    let payee: String?
    let payee_name: String?
    let imported_payee: String?
    let category: String?
    let notes: String?
    let imported_id: String?
    let transfer_id: String?
    let cleared: Bool?
    let subtransactions: [Transaction]?
}

struct TransactionsListResponse: Decodable {
    let data: [Transaction]
}

struct BudgetMonth: Decodable {
    let month: String
    let incomeAvailable: Int
    let lastMonthOverspent: Int
    let forNextMonth: Int
    let totalBudgeted: Int
    let toBudget: Int
    let fromLastMonth: Int
    let totalIncome: Int
    let totalSpent: Int
    let totalBalance: Int
}

struct BudgetMonthCategory: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let is_income: Bool?
    let hidden: Bool?
    let group_id: String?
    let budgeted: Int?
    let spent: Int?
    let balance: Int?
    let carryover: Bool?
}

struct BudgetMonthCategoryGroup: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let is_income: Bool?
    let hidden: Bool?
    let categories: [BudgetMonthCategory]?
    let budgeted: Int?
    let spent: Int?
    let balance: Int?
}

struct BudgetMonthCategoriesResponse: Decodable { let data: [BudgetMonthCategory] }
struct BudgetMonthCategoryGroupsResponse: Decodable { let data: [BudgetMonthCategoryGroup] }