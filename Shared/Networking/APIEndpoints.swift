import Foundation

enum APIEndpoints {
    static func baseURL(from baseURLString: String) throws -> URL {
        guard let url = URL(string: baseURLString) else { throw URLError(.badURL) }
        return url
    }

    static func accounts(base: URL, syncId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts") }
    static func account(base: URL, syncId: String, accountId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)") }
    static func accountBalance(base: URL, syncId: String, accountId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)/balance") }
    static func accountClose(base: URL, syncId: String, accountId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)/close") }
    static func accountReopen(base: URL, syncId: String, accountId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)/reopen") }
    static func accountBankSync(base: URL, syncId: String, accountId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)/banksync") }
    static func accountsBankSync(base: URL, syncId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/accounts/banksync") }

    static func categories(base: URL, syncId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/categories") }
    static func payees(base: URL, syncId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/payees") }

    static func accountTransactions(base: URL, syncId: String, accountId: String, since: String?, until: String?, page: Int?, limit: Int?) -> URLComponents {
        var comps = URLComponents(url: base.appendingPathComponent("/budgets/\(syncId)/accounts/\(accountId)/transactions"), resolvingAgainstBaseURL: false)!
        var q: [URLQueryItem] = []
        if let since { q.append(URLQueryItem(name: "since_date", value: since)) }
        if let until { q.append(URLQueryItem(name: "until_date", value: until)) }
        if let page { q.append(URLQueryItem(name: "page", value: String(page))) }
        if let limit { q.append(URLQueryItem(name: "limit", value: String(limit))) }
        comps.queryItems = q.isEmpty ? nil : q
        return comps
    }

    static func transaction(base: URL, syncId: String, transactionId: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/transactions/\(transactionId)") }
    static func month(base: URL, syncId: String, month: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/months/\(month)") }
    static func monthCategoryGroups(base: URL, syncId: String, month: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/months/\(month)/categorygroups") }
    static func monthCategories(base: URL, syncId: String, month: String) -> URL { base.appendingPathComponent("/budgets/\(syncId)/months/\(month)/categories") }
}