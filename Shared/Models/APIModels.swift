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
    /// Income categories in Actual expose `received` instead of `spent`.
    /// Present for income categories, nil for expense categories.
    let received: Int?
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

// MARK: - Notes

/// Response payload for `/notes/{entity}/{id}` endpoints. `data` is the note
/// text, or nil if the entity has no note attached.
struct NoteResponse: Decodable { let data: String? }

struct NoteRequest: Encodable { let data: String }

// MARK: - Schedules

enum ScheduleAmountOp: String, Codable, CaseIterable, Identifiable {
    case `is`
    case isapprox
    case isbetween
    var id: String { rawValue }

    var label: String {
        switch self {
        case .is: return "Exactly"
        case .isapprox: return "Approximately"
        case .isbetween: return "Between"
        }
    }
}

/// `amount` in a schedule can be a plain number (for `is`/`isapprox`) or an
/// object `{ num1, num2 }` (for `isbetween`). Modeled as an enum with a custom
/// `Codable` conformance that dispatches on the JSON shape.
enum ScheduleAmount: Equatable {
    case exact(Int)
    case range(Int, Int)
}

extension ScheduleAmount: Codable {
    private enum RangeKeys: String, CodingKey { case num1, num2 }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .exact(int)
            return
        }
        if let dbl = try? container.decode(Double.self) {
            self = .exact(Int(dbl))
            return
        }
        let keyed = try decoder.container(keyedBy: RangeKeys.self)
        let n1 = try keyed.decode(Int.self, forKey: .num1)
        let n2 = try keyed.decode(Int.self, forKey: .num2)
        self = .range(n1, n2)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .exact(let v):
            var c = encoder.singleValueContainer()
            try c.encode(v)
        case .range(let a, let b):
            var c = encoder.container(keyedBy: RangeKeys.self)
            try c.encode(a, forKey: .num1)
            try c.encode(b, forKey: .num2)
        }
    }
}

enum RecurFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum RecurEndMode: String, Codable, CaseIterable, Identifiable {
    case never
    case afterN = "after_n_occurrences"
    case onDate = "on_date"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .never: return "Never"
        case .afterN: return "After N occurrences"
        case .onDate: return "On date"
        }
    }
}

struct RecurConfig: Codable, Equatable {
    var frequency: RecurFrequency
    var interval: Int?
    var skipWeekend: Bool?
    var start: String
    var endMode: RecurEndMode?
    var endOccurrences: Int?
    var endDate: String?
    var weekendSolveMode: String?
}

/// `date` on a schedule is either an ISO date string (single-occurrence) or a
/// `RecurConfig` object (recurring).
enum ScheduleDate: Equatable {
    case once(String)
    case recurring(RecurConfig)
}

extension ScheduleDate: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .once(str)
            return
        }
        let cfg = try RecurConfig(from: decoder)
        self = .recurring(cfg)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .once(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .recurring(let cfg):
            try cfg.encode(to: encoder)
        }
    }
}

struct Schedule: Identifiable, Codable, Equatable {
    let id: String
    var name: String?
    var rule: String?
    var next_date: String?
    var completed: Bool?
    var posts_transaction: Bool?
    var payee: String?
    var account: String?
    var amount: ScheduleAmount?
    var amountOp: ScheduleAmountOp?
    var date: ScheduleDate?
}

/// Payload for creating/updating a schedule. Omits server-derived fields
/// (`id`, `rule`, `next_date`, `completed`). `date` is required on create.
struct ScheduleInput: Encodable, Equatable {
    var name: String?
    var posts_transaction: Bool?
    var payee: String?
    var account: String?
    var amount: ScheduleAmount?
    var amountOp: ScheduleAmountOp?
    var date: ScheduleDate
}

struct SchedulesListResponse: Decodable { let data: [Schedule] }
struct ScheduleResponse: Decodable { let data: Schedule }
struct ScheduleCreateResponse: Decodable { let data: String }