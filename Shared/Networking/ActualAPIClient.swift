import Foundation

final class ActualAPIClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let syncId: String
    private let budgetEncryptionPassword: String?
    private let isDemoMode: Bool

    init(baseURLString: String, apiKey: String, syncId: String, budgetEncryptionPassword: String?, isDemoMode: Bool = false) throws {
        self.session = URLSession(configuration: .default)
        self.isDemoMode = isDemoMode
        if isDemoMode {
            self.baseURL = URL(string: "https://demo.local")!
        } else {
            self.baseURL = try APIEndpoints.baseURL(from: baseURLString)
        }
        self.apiKey = apiKey
        self.syncId = syncId
        self.budgetEncryptionPassword = budgetEncryptionPassword?.isEmpty == true ? nil : budgetEncryptionPassword
    }


    func fetchAccounts() async throws -> [Account] {
        if isDemoMode {
            return DemoDataService.shared.generateAccounts()
        }
        let url = APIEndpoints.accounts(base: baseURL, syncId: syncId)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(AccountsListResponse.self, from: data, request: request, context: "fetchAccounts").data
    }

    func fetchCategories() async throws -> [Category] {
        if isDemoMode {
            return DemoDataService.shared.generateCategories()
        }
        let url = APIEndpoints.categories(base: baseURL, syncId: syncId)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(CategoriesListResponse.self, from: data, request: request, context: "fetchCategories").data
    }

    func fetchPayees() async throws -> [Payee] {
        if isDemoMode {
            return DemoDataService.shared.generatePayees()
        }
        let url = APIEndpoints.payees(base: baseURL, syncId: syncId)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(PayeesListResponse.self, from: data, request: request, context: "fetchPayees").data
    }

    func fetchTransactions(accountId: String, since: String? = nil, until: String? = nil, page: Int? = nil, limit: Int? = nil) async throws -> [Transaction] {
        if isDemoMode {
            return DemoDataService.shared.generateTransactions(for: accountId, since: since ?? "2024-01-01")
        }
        let comps = APIEndpoints.accountTransactions(base: baseURL, syncId: syncId, accountId: accountId, since: since, until: until, page: page, limit: limit)
        let request = try buildRequest(url: try requireURL(comps), method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(TransactionsListResponse.self, from: data, request: request, context: "fetchTransactions").data
    }

    func createTransaction(accountId: String, transaction: Transaction, learnCategories: Bool = false, runTransfers: Bool = false) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.accountTransactions(base: baseURL, syncId: syncId, accountId: accountId, since: nil, until: nil, page: nil, limit: nil).url!
        var request = try buildRequest(url: url, method: "POST")
        var body: [String: Any] = [
            "learnCategories": learnCategories,
            "runTransfers": runTransfers
        ]
        body["transaction"] = serialize(transaction)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func updateTransaction(transactionId: String, transaction: Transaction) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.transaction(base: baseURL, syncId: syncId, transactionId: transactionId)
        var request = try buildRequest(url: url, method: "PATCH")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["transaction": serialize(transaction)])
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func deleteTransaction(transactionId: String) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.transaction(base: baseURL, syncId: syncId, transactionId: transactionId)
        let request = try buildRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func fetchBudgetMonth(_ month: String) async throws -> BudgetMonth {
        if isDemoMode {
            return DemoDataService.shared.generateBudgetMonth()
        }
        let url = APIEndpoints.month(base: baseURL, syncId: syncId, month: month)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(APIResponse<BudgetMonth>.self, from: data, request: request, context: "fetchBudgetMonth").data
    }
    
    func fetchBudgetMonthCategoryGroups(_ month: String) async throws -> [BudgetMonthCategoryGroup] {
        if isDemoMode {
            return DemoDataService.shared.generateBudgetCategoryGroups()
        }
        let url = APIEndpoints.monthCategoryGroups(base: baseURL, syncId: syncId, month: month)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        // Debug: dump the income-category payload so we can verify field names
        // (spent vs received vs something else). Safe to remove once the
        // income bug is confirmed fixed against a real server.
        logIncomeCategoriesSample(data: data)
        return try decodeOrLog(BudgetMonthCategoryGroupsResponse.self, from: data, request: request, context: "fetchBudgetMonthCategoryGroups").data
    }

    private func logIncomeCategoriesSample(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["data"] as? [[String: Any]] else { return }
        for group in groups where (group["is_income"] as? Bool) == true {
            let name = group["name"] as? String ?? "?"
            let cats = group["categories"] as? [[String: Any]] ?? []
            AppLogger.shared.log(
                "Income group sample",
                level: .info,
                context: "fetchBudgetMonthCategoryGroups",
                metadata: [
                    "group": name,
                    "groupKeys": Array(group.keys).sorted(),
                    "categoryCount": cats.count,
                    "firstCategory": cats.first ?? [:]
                ]
            )
        }
    }

    func createAccount(name: String, offbudget: Bool) async throws -> String {
        if isDemoMode { return "demo-account-\(UUID().uuidString.prefix(8))" }
        let url = APIEndpoints.accounts(base: baseURL, syncId: syncId)
        var request = try buildRequest(url: url, method: "POST")
        let body: [String: Any] = [
            "account": [
                "name": name,
                "offbudget": offbudget
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        let msg = try decodeOrLog(GeneralResponseMessage.self, from: data, request: request, context: "createAccount")
        return msg.message
    }
    
    func deleteAccount(accountId: String) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.account(base: baseURL, syncId: syncId, accountId: accountId)
        let request = try buildRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func closeAccount(accountId: String, transferAccountId: String?, transferCategoryId: String?) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.accountClose(base: baseURL, syncId: syncId, accountId: accountId)
        var request = try buildRequest(url: url, method: "PUT")
        var transfer: [String: Any] = [:]
        if let transferAccountId { transfer["transferAccountId"] = transferAccountId }
        if let transferCategoryId { transfer["transferCategoryId"] = transferCategoryId }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["transfer": transfer])
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func fetchAccountBalance(accountId: String) async throws -> Int {
        if isDemoMode {
            let since = DemoDataService.shared.demoSinceDateString(daysBack: 120)
            return DemoDataService.shared.generateTransactions(for: accountId, since: since)
                .compactMap { $0.amount }
                .reduce(0, +)
        }
        let url = APIEndpoints.accountBalance(base: baseURL, syncId: syncId, accountId: accountId)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(APIResponse<Int>.self, from: data, request: request, context: "fetchAccountBalance").data
    }

    func reopenAccount(accountId: String) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.accountReopen(base: baseURL, syncId: syncId, accountId: accountId)
        let request = try buildRequest(url: url, method: "PUT")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func bankSync(accountId: String?) async throws {
        if isDemoMode { return }
        let url: URL
        if let accountId {
            url = APIEndpoints.accountBankSync(base: baseURL, syncId: syncId, accountId: accountId)
        } else {
            url = APIEndpoints.accountsBankSync(base: baseURL, syncId: syncId)
        }
        let request = try buildRequest(url: url, method: "POST")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    // MARK: - Schedules

    func fetchSchedules() async throws -> [Schedule] {
        if isDemoMode { return DemoDataService.shared.generateSchedules() }
        let url = APIEndpoints.schedules(base: baseURL, syncId: syncId)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        do {
            try ensureSuccess(response: response, data: data)
        } catch APIError.httpError(let status, _) where status == 404 {
            throw APIError.unsupportedEndpoint
        }
        return try decodeOrLog(SchedulesListResponse.self, from: data, request: request, context: "fetchSchedules").data
    }

    func fetchSchedule(id: String) async throws -> Schedule {
        if isDemoMode {
            return DemoDataService.shared.generateSchedules().first { $0.id == id }
                ?? Schedule(id: id, name: nil, rule: nil, next_date: nil, completed: nil, posts_transaction: nil, payee: nil, account: nil, amount: nil, amountOp: nil, date: nil)
        }
        let url = APIEndpoints.schedule(base: baseURL, syncId: syncId, id: id)
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(ScheduleResponse.self, from: data, request: request, context: "fetchSchedule").data
    }

    func createSchedule(_ input: ScheduleInput) async throws -> String {
        if isDemoMode { return "demo-schedule-\(UUID().uuidString.prefix(8))" }
        let url = APIEndpoints.schedules(base: baseURL, syncId: syncId)
        var request = try buildRequest(url: url, method: "POST")
        let wrapped = ScheduleWrapper(schedule: input)
        request.httpBody = try JSONEncoder().encode(wrapped)
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(ScheduleCreateResponse.self, from: data, request: request, context: "createSchedule").data
    }

    func updateSchedule(id: String, _ input: ScheduleInput) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.schedule(base: baseURL, syncId: syncId, id: id)
        var request = try buildRequest(url: url, method: "PATCH")
        let wrapped = ScheduleWrapper(schedule: input)
        request.httpBody = try JSONEncoder().encode(wrapped)
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    func deleteSchedule(id: String) async throws {
        if isDemoMode { return }
        let url = APIEndpoints.schedule(base: baseURL, syncId: syncId, id: id)
        let request = try buildRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    // MARK: - Notes

    func fetchCategoryNotes(categoryId: String) async throws -> String? {
        try await fetchNotes(url: APIEndpoints.categoryNotes(base: baseURL, syncId: syncId, categoryId: categoryId), context: "fetchCategoryNotes")
    }

    func setCategoryNotes(categoryId: String, text: String) async throws {
        try await putNotes(url: APIEndpoints.categoryNotes(base: baseURL, syncId: syncId, categoryId: categoryId), text: text)
    }

    func deleteCategoryNotes(categoryId: String) async throws {
        try await deleteNotes(url: APIEndpoints.categoryNotes(base: baseURL, syncId: syncId, categoryId: categoryId))
    }

    func fetchAccountNotes(accountId: String) async throws -> String? {
        try await fetchNotes(url: APIEndpoints.accountNotes(base: baseURL, syncId: syncId, accountId: accountId), context: "fetchAccountNotes")
    }

    func setAccountNotes(accountId: String, text: String) async throws {
        try await putNotes(url: APIEndpoints.accountNotes(base: baseURL, syncId: syncId, accountId: accountId), text: text)
    }

    func deleteAccountNotes(accountId: String) async throws {
        try await deleteNotes(url: APIEndpoints.accountNotes(base: baseURL, syncId: syncId, accountId: accountId))
    }

    func fetchBudgetMonthNotes(month: String) async throws -> String? {
        try await fetchNotes(url: APIEndpoints.budgetMonthNotes(base: baseURL, syncId: syncId, month: month), context: "fetchBudgetMonthNotes")
    }

    func setBudgetMonthNotes(month: String, text: String) async throws {
        try await putNotes(url: APIEndpoints.budgetMonthNotes(base: baseURL, syncId: syncId, month: month), text: text)
    }

    func deleteBudgetMonthNotes(month: String) async throws {
        try await deleteNotes(url: APIEndpoints.budgetMonthNotes(base: baseURL, syncId: syncId, month: month))
    }

    private func fetchNotes(url: URL, context: String) async throws -> String? {
        if isDemoMode { return DemoDataService.shared.demoNote(for: url.path) }
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
        return try decodeOrLog(NoteResponse.self, from: data, request: request, context: context).data
    }

    private func putNotes(url: URL, text: String) async throws {
        if isDemoMode { return }
        var request = try buildRequest(url: url, method: "PUT")
        request.httpBody = try JSONEncoder().encode(NoteRequest(data: text))
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    private func deleteNotes(url: URL) async throws {
        if isDemoMode { return }
        let request = try buildRequest(url: url, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try ensureSuccess(response: response, data: data)
    }

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let budgetEncryptionPassword { request.setValue(budgetEncryptionPassword, forHTTPHeaderField: "budget-encryption-password") }
        return request
    }

    private func requireURL(_ components: URLComponents) throws -> URL {
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func ensureSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? ""
            if let req = (response as? HTTPURLResponse)?.url {
                NetworkLogger.logHTTPError(method: "", url: req, baseURLString: baseURL.absoluteString, status: http.statusCode, body: data)
            } else {
                AppLogger.shared.log("HTTP Error", level: .error, context: "ActualAPIClient.ensureSuccess", metadata: ["status": http.statusCode, "body": serverMessage])
            }
            throw APIError.httpError(status: http.statusCode, body: serverMessage)
        }
    }

    private func decodeOrLog<T: Decodable>(_ type: T.Type, from data: Data, request: URLRequest, context: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Build minimal request context without base URL
            var md: [String: Any] = ["context": context]
            if let url = request.url {
                let full = url.absoluteString
                let base = baseURL.absoluteString
                let path = full.hasPrefix(base) ? String(full.dropFirst(base.count)) : (URLComponents(url: url, resolvingAgainstBaseURL: false)?.url?.path ?? full)
                md["method"] = request.httpMethod ?? ""
                md["path"] = path
            }
            let sample = String(data: data.prefix(4096), encoding: .utf8) ?? "<non-utf8>"
            md["responseSample"] = sample
            md["decodeError"] = String(describing: error)
            AppLogger.shared.log("Decode Error", level: .error, context: "ActualAPIClient", metadata: md)
            throw error
        }
    }

    private func serialize(_ tx: Transaction) -> [String: Any] {
        var dict: [String: Any] = [
            "account": tx.account,
            "date": tx.date
        ]
        if let id = tx.id { dict["id"] = id }
        if let amount = tx.amount { dict["amount"] = amount }
        if let payee = tx.payee { dict["payee"] = payee }
        if let payeeName = tx.payee_name { dict["payee_name"] = payeeName }
        if let category = tx.category { dict["category"] = category }
        if let notes = tx.notes { dict["notes"] = notes }
        if let importedId = tx.imported_id { dict["imported_id"] = importedId }
        if let transferId = tx.transfer_id { dict["transfer_id"] = transferId }
        if let cleared = tx.cleared { dict["cleared"] = cleared }
        return dict
    }
}

enum APIError: Error, LocalizedError {
    case httpError(status: Int, body: String)
    case unsupportedEndpoint

    var errorDescription: String? {
        switch self {
        case let .httpError(status, body):
            return "HTTP \(status): \(body)"
        case .unsupportedEndpoint:
            return "This endpoint is not supported by the server."
        }
    }
}

private struct ScheduleWrapper: Encodable {
    let schedule: ScheduleInput
}