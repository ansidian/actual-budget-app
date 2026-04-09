import SwiftUI

/// Editor form for creating or editing a transaction. Designed to live in an
/// Inspector pane or sheet on macOS.
struct MacTransactionEditor: View {
    enum PayeeInputMode: String, CaseIterable, Identifiable {
        case picker = "Choose"
        case custom = "Custom"
        var id: String { rawValue }
    }

    let transaction: Transaction?
    let initialAccountId: String?
    let accounts: [Account]
    let payees: [Payee]
    let categoriesById: [String: String]
    let onSave: (Transaction) -> Void
    let onCancel: () -> Void

    @State private var date: Date
    @State private var amountString: String
    @State private var isExpense: Bool
    @State private var selectedPayeeId: String
    @State private var customPayee: String
    @State private var payeeMode: PayeeInputMode
    @State private var notes: String
    @State private var categoryId: String?
    @State private var selectedAccountId: String
    @State private var selectedTransferId: String?

    init(
        transaction: Transaction?,
        initialAccountId: String?,
        accounts: [Account],
        payees: [Payee],
        categoriesById: [String: String],
        onSave: @escaping (Transaction) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.initialAccountId = initialAccountId
        self.accounts = accounts
        self.payees = payees
        self.categoriesById = categoriesById
        self.onSave = onSave
        self.onCancel = onCancel

        if let t = transaction {
            _date = State(initialValue: Self.parseDate(t.date) ?? Date())
            _amountString = State(initialValue: Self.formatAmountForDisplay(abs(t.amount ?? 0)))
            _isExpense = State(initialValue: (t.amount ?? 0) < 0)

            if let payeeId = t.payee, !payeeId.isEmpty {
                _selectedPayeeId = State(initialValue: payeeId)
                _payeeMode = State(initialValue: .picker)
                _customPayee = State(initialValue: "")
            } else if let payeeName = t.payee_name, !payeeName.isEmpty {
                _customPayee = State(initialValue: payeeName)
                _payeeMode = State(initialValue: .custom)
                _selectedPayeeId = State(initialValue: "")
            } else {
                _payeeMode = State(initialValue: .picker)
                _selectedPayeeId = State(initialValue: "")
                _customPayee = State(initialValue: "")
            }

            _notes = State(initialValue: t.notes ?? "")
            _categoryId = State(initialValue: t.category)
            _selectedAccountId = State(initialValue: t.account)
            _selectedTransferId = State(initialValue: t.transfer_id)
        } else {
            _date = State(initialValue: Date())
            _amountString = State(initialValue: "0.00")
            _isExpense = State(initialValue: true)
            _selectedPayeeId = State(initialValue: "")
            _customPayee = State(initialValue: "")
            _payeeMode = State(initialValue: .picker)
            _notes = State(initialValue: "")
            _categoryId = State(initialValue: nil)
            _selectedAccountId = State(initialValue: initialAccountId ?? accounts.first?.id ?? "")
            _selectedTransferId = State(initialValue: nil)
        }
    }

    private var sortedCategories: [(key: String, value: String)] {
        categoriesById.sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var canSave: Bool {
        !selectedAccountId.isEmpty && !amountString.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Account") {
                    Picker("Account", selection: $selectedAccountId) {
                        ForEach(accounts.filter { !$0.closed }, id: \.id) { acc in
                            Text(acc.name + (acc.offbudget ? " (Off-Budget)" : "")).tag(acc.id)
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Amount", text: $amountString)
                    Picker("Type", selection: $isExpense) {
                        Text("Expense").tag(true)
                        Text("Income").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Payee") {
                    Picker("Mode", selection: $payeeMode) {
                        ForEach(PayeeInputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if payeeMode == .picker {
                        Picker("Payee", selection: $selectedPayeeId) {
                            Text("None").tag("")
                            ForEach(payees.sorted { $0.name < $1.name }, id: \.id) { payee in
                                Text(payee.name).tag(payee.id)
                            }
                        }
                        .onChange(of: selectedPayeeId) { _, newValue in
                            selectedTransferId = payees.first { $0.id == newValue }?.transfer_acct
                        }
                    } else {
                        TextField("Payee Name", text: $customPayee)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $categoryId) {
                        Text("None").tag(String?.none)
                        ForEach(sortedCategories, id: \.key) { entry in
                            Text(entry.value).tag(String?.some(entry.key))
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(transaction == nil ? "Add" : "Save") {
                    onSave(buildTransaction())
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(12)
        }
    }

    private func buildTransaction() -> Transaction {
        let units = parseAmount(amountString)
        let signed = isExpense ? -abs(units) : abs(units)

        let payeeId: String? = payeeMode == .picker
            ? (selectedPayeeId.isEmpty ? nil : selectedPayeeId)
            : nil
        let payeeName: String? = payeeMode == .custom
            ? (customPayee.isEmpty ? nil : customPayee)
            : nil

        return Transaction(
            id: transaction?.id,
            account: selectedAccountId,
            date: Self.formatDate(date),
            amount: signed,
            payee: payeeId,
            payee_name: payeeName,
            imported_payee: nil,
            category: categoryId,
            notes: notes.isEmpty ? nil : notes,
            imported_id: nil,
            transfer_id: selectedTransferId,
            cleared: false,
            subtransactions: nil
        )
    }

    private func parseAmount(_ display: String) -> Int {
        let normalized = display.replacingOccurrences(of: ",", with: ".")
        return Int((Double(normalized) ?? 0.0) * 100)
    }

    private static func parseDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func formatAmountForDisplay(_ amount: Int) -> String {
        String(format: "%.2f", Double(amount) / 100.0)
    }
}
