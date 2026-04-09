import SwiftUI

struct MacSchedulesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: SchedulesViewModel?
    @State private var accounts: [Account] = []
    @State private var payees: [Payee] = []
    @State private var selection: Schedule.ID?
    @State private var editorState: EditorState = .closed

    private enum EditorState: Equatable {
        case closed
        case creating
        case editing(String)
        var isOpen: Bool { self != .closed }
    }

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editorState = .creating
                } label: {
                    Label("New Schedule", systemImage: "plus")
                }
                .disabled(vm == nil)
                Button {
                    Task { await vm?.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(vm == nil)
            }
        }
        .task {
            if vm == nil {
                vm = SchedulesViewModel(appState: appState)
                await vm?.load()
                await loadLookups()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            Task { await vm?.load() }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { vm?.errorMessage = nil }
        } message: {
            Text(vm?.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm?.errorMessage != nil },
            set: { if !$0 { vm?.errorMessage = nil } }
        )
    }

    @ViewBuilder
    private func content(vm: SchedulesViewModel) -> some View {
        if vm.endpointUnsupported {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Schedules not supported")
                    .font(.headline)
                Text("Your Actual server version does not expose the schedules API.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            let rows = vm.filteredSchedules.sorted {
                ($0.next_date ?? "") < ($1.next_date ?? "")
            }
            VStack(spacing: 0) {
                filterBar(vm: vm)
                Divider()
                schedulesTable(vm: vm, rows: rows)
            }
            .inspector(isPresented: Binding(
                get: { editorState.isOpen },
                set: { if !$0 { editorState = .closed } }
            )) {
                editorPane(vm: vm)
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 520)
            }
        }
    }

    @ViewBuilder
    private func filterBar(vm: SchedulesViewModel) -> some View {
        HStack(spacing: 16) {
            Picker("Filter", selection: Binding(get: { vm.filter }, set: { vm.filter = $0 })) {
                ForEach(SchedulesViewModel.Filter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func schedulesTable(vm: SchedulesViewModel, rows: [Schedule]) -> some View {
        Table(rows, selection: $selection) {
            TableColumn("Name") { (s: Schedule) in
                Text(s.name ?? "(Unnamed)")
            }
            .width(min: 100, ideal: 160)

            TableColumn("Next Date") { (s: Schedule) in
                Text(s.next_date ?? "—")
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Amount") { (s: Schedule) in
                amountText(s.amount)
            }
            .width(min: 90, ideal: 130)

            TableColumn("Account") { (s: Schedule) in
                Text(accountName(for: s.account))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Payee") { (s: Schedule) in
                Text(payeeName(for: s.payee))
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Frequency") { (s: Schedule) in
                Text(frequencyLabel(s.date))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 110)

            TableColumn("Posts") { (s: Schedule) in
                Image(systemName: (s.posts_transaction ?? false) ? "checkmark" : "minus")
                    .foregroundStyle(.secondary)
            }
            .width(50)

            TableColumn("Completed") { (s: Schedule) in
                Image(systemName: (s.completed ?? false) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle((s.completed ?? false) ? .green : .secondary)
            }
            .width(70)
        }
        .contextMenu(forSelectionType: Schedule.ID.self) { ids in
            Button("Edit") {
                if let id = ids.first { editorState = .editing(id) }
            }.disabled(ids.count != 1)
            Button("Delete", role: .destructive) {
                Task {
                    for id in ids { await vm.delete(id: id) }
                }
            }.disabled(ids.isEmpty)
        } primaryAction: { ids in
            if let id = ids.first { editorState = .editing(id) }
        }
        .onDeleteCommand {
            guard let id = selection else { return }
            Task { await vm.delete(id: id) }
            selection = nil
        }
    }

    @ViewBuilder
    private func editorPane(vm: SchedulesViewModel) -> some View {
        switch editorState {
        case .closed:
            EmptyView()
        case .creating:
            MacScheduleEditor(
                schedule: nil,
                accounts: accounts,
                payees: payees,
                onSave: { input in
                    Task {
                        await vm.create(input)
                        editorState = .closed
                    }
                },
                onCancel: { editorState = .closed }
            )
        case .editing(let id):
            if let s = vm.schedules.first(where: { $0.id == id }) {
                MacScheduleEditor(
                    schedule: s,
                    accounts: accounts,
                    payees: payees,
                    onSave: { input in
                        Task {
                            await vm.update(id: id, input)
                            editorState = .closed
                        }
                    },
                    onCancel: { editorState = .closed }
                )
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func amountText(_ amount: ScheduleAmount?) -> some View {
        switch amount {
        case .none:
            Text("—").foregroundStyle(.secondary)
        case .some(.exact(let v)):
            MoneyText(amount: v, currencyCode: appState.currencyCode, signed: true)
        case .some(.range(let lo, let hi)):
            let f = CurrencyFormatter.shared
            Text("\(f.format(lo, currencyCode: appState.currencyCode)) – \(f.format(hi, currencyCode: appState.currencyCode))")
        }
    }

    private func accountName(for id: String?) -> String {
        guard let id else { return "—" }
        return accounts.first { $0.id == id }?.name ?? "—"
    }

    private func payeeName(for id: String?) -> String {
        guard let id else { return "—" }
        return payees.first { $0.id == id }?.name ?? "—"
    }

    private func frequencyLabel(_ date: ScheduleDate?) -> String {
        switch date {
        case .none: return "—"
        case .some(.once): return "One-off"
        case .some(.recurring(let cfg)):
            let interval = cfg.interval ?? 1
            if interval == 1 {
                return cfg.frequency.label
            }
            return "\(cfg.frequency.label) (every \(interval))"
        }
    }

    private func loadLookups() async {
        do {
            let client = try ActualAPIClient(
                baseURLString: appState.baseURLString,
                apiKey: appState.apiKey,
                syncId: appState.syncId,
                budgetEncryptionPassword: appState.budgetEncryptionPassword,
                isDemoMode: appState.isDemoMode
            )
            async let a = client.fetchAccounts()
            async let p = client.fetchPayees()
            let (accs, pys) = try await (a, p)
            self.accounts = accs
            self.payees = pys
        } catch {
            AppLogger.shared.log(error: error, context: "MacSchedulesView.loadLookups")
        }
    }
}

/// Editor for creating or editing a schedule. Covers the subset of fields
/// listed in the plan: name, payee/account pickers, amount + op, one-off vs
/// recurring date, RecurConfig fields, posts_transaction flag. Read-only
/// display for rule / next_date / completed.
private struct MacScheduleEditor: View {
    let schedule: Schedule?
    let accounts: [Account]
    let payees: [Payee]
    let onSave: (ScheduleInput) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var selectedAccountId: String
    @State private var selectedPayeeId: String
    @State private var postsTransaction: Bool

    // Amount
    @State private var amountOp: ScheduleAmountOp
    @State private var amountExact: String
    @State private var amountLow: String
    @State private var amountHigh: String

    // Date
    @State private var isRecurring: Bool
    @State private var onceDate: Date
    @State private var frequency: RecurFrequency
    @State private var interval: Int
    @State private var skipWeekend: Bool
    @State private var startDate: Date
    @State private var endMode: RecurEndMode
    @State private var endOccurrences: Int
    @State private var endDate: Date

    init(schedule: Schedule?, accounts: [Account], payees: [Payee], onSave: @escaping (ScheduleInput) -> Void, onCancel: @escaping () -> Void) {
        self.schedule = schedule
        self.accounts = accounts
        self.payees = payees
        self.onSave = onSave
        self.onCancel = onCancel

        _name = State(initialValue: schedule?.name ?? "")
        _selectedAccountId = State(initialValue: schedule?.account ?? accounts.first?.id ?? "")
        _selectedPayeeId = State(initialValue: schedule?.payee ?? "")
        _postsTransaction = State(initialValue: schedule?.posts_transaction ?? false)

        let op = schedule?.amountOp ?? .is
        _amountOp = State(initialValue: op)
        switch schedule?.amount {
        case .some(.exact(let v)):
            _amountExact = State(initialValue: Self.formatCents(abs(v)))
            _amountLow = State(initialValue: "0.00")
            _amountHigh = State(initialValue: "0.00")
        case .some(.range(let lo, let hi)):
            _amountExact = State(initialValue: "0.00")
            _amountLow = State(initialValue: Self.formatCents(abs(lo)))
            _amountHigh = State(initialValue: Self.formatCents(abs(hi)))
        case .none:
            _amountExact = State(initialValue: "0.00")
            _amountLow = State(initialValue: "0.00")
            _amountHigh = State(initialValue: "0.00")
        }

        switch schedule?.date {
        case .some(.once(let str)):
            _isRecurring = State(initialValue: false)
            _onceDate = State(initialValue: Self.parseDate(str) ?? Date())
            _frequency = State(initialValue: .monthly)
            _interval = State(initialValue: 1)
            _skipWeekend = State(initialValue: false)
            _startDate = State(initialValue: Date())
            _endMode = State(initialValue: .never)
            _endOccurrences = State(initialValue: 1)
            _endDate = State(initialValue: Date())
        case .some(.recurring(let cfg)):
            _isRecurring = State(initialValue: true)
            _onceDate = State(initialValue: Date())
            _frequency = State(initialValue: cfg.frequency)
            _interval = State(initialValue: cfg.interval ?? 1)
            _skipWeekend = State(initialValue: cfg.skipWeekend ?? false)
            _startDate = State(initialValue: Self.parseDate(cfg.start) ?? Date())
            _endMode = State(initialValue: cfg.endMode ?? .never)
            _endOccurrences = State(initialValue: cfg.endOccurrences ?? 1)
            _endDate = State(initialValue: (cfg.endDate.flatMap(Self.parseDate)) ?? Date())
        case .none:
            _isRecurring = State(initialValue: false)
            _onceDate = State(initialValue: Date())
            _frequency = State(initialValue: .monthly)
            _interval = State(initialValue: 1)
            _skipWeekend = State(initialValue: false)
            _startDate = State(initialValue: Date())
            _endMode = State(initialValue: .never)
            _endOccurrences = State(initialValue: 1)
            _endDate = State(initialValue: Date())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Account", selection: $selectedAccountId) {
                        Text("None").tag("")
                        ForEach(accounts.filter { !$0.closed }, id: \.id) { a in
                            Text(a.name).tag(a.id)
                        }
                    }
                    Picker("Payee", selection: $selectedPayeeId) {
                        Text("None").tag("")
                        ForEach(payees.sorted { $0.name < $1.name }, id: \.id) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    Toggle("Posts transaction", isOn: $postsTransaction)
                }

                Section("Amount") {
                    Picker("Match", selection: $amountOp) {
                        ForEach(ScheduleAmountOp.allCases) { op in
                            Text(op.label).tag(op)
                        }
                    }
                    if amountOp == .isbetween {
                        TextField("Low", text: $amountLow)
                        TextField("High", text: $amountHigh)
                    } else {
                        TextField("Amount", text: $amountExact)
                    }
                }

                Section("Date") {
                    Picker("Type", selection: $isRecurring) {
                        Text("One-off").tag(false)
                        Text("Recurring").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isRecurring {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        Picker("Frequency", selection: $frequency) {
                            ForEach(RecurFrequency.allCases) { f in
                                Text(f.label).tag(f)
                            }
                        }
                        Stepper(value: $interval, in: 1...52) {
                            Text("Every \(interval)")
                                .monospacedDigit()
                        }
                        Toggle("Skip weekend", isOn: $skipWeekend)
                        Picker("End", selection: $endMode) {
                            ForEach(RecurEndMode.allCases) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        if endMode == .afterN {
                            Stepper(value: $endOccurrences, in: 1...999) {
                                Text("\(endOccurrences) occurrences")
                                    .monospacedDigit()
                            }
                        } else if endMode == .onDate {
                            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        }
                    } else {
                        DatePicker("Date", selection: $onceDate, displayedComponents: .date)
                    }
                }

                if let s = schedule {
                    Section("Server-managed") {
                        LabeledContent("Next date", value: s.next_date ?? "—")
                        LabeledContent("Completed", value: (s.completed ?? false) ? "Yes" : "No")
                        LabeledContent("Rule", value: s.rule ?? "—")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(schedule == nil ? "Create" : "Save") {
                    onSave(buildInput())
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(12)
        }
    }

    private var canSave: Bool { !selectedAccountId.isEmpty }

    private func buildInput() -> ScheduleInput {
        let amount: ScheduleAmount?
        switch amountOp {
        case .is, .isapprox:
            amount = .exact(-abs(Self.parseCents(amountExact)))
        case .isbetween:
            amount = .range(-abs(Self.parseCents(amountLow)), -abs(Self.parseCents(amountHigh)))
        }

        let date: ScheduleDate
        if isRecurring {
            date = .recurring(RecurConfig(
                frequency: frequency,
                interval: interval,
                skipWeekend: skipWeekend ? true : nil,
                start: Self.formatDate(startDate),
                endMode: endMode,
                endOccurrences: endMode == .afterN ? endOccurrences : nil,
                endDate: endMode == .onDate ? Self.formatDate(endDate) : nil,
                weekendSolveMode: nil
            ))
        } else {
            date = .once(Self.formatDate(onceDate))
        }

        return ScheduleInput(
            name: name.isEmpty ? nil : name,
            posts_transaction: postsTransaction,
            payee: selectedPayeeId.isEmpty ? nil : selectedPayeeId,
            account: selectedAccountId.isEmpty ? nil : selectedAccountId,
            amount: amount,
            amountOp: amountOp,
            date: date
        )
    }

    private static func parseCents(_ str: String) -> Int {
        let normalized = str.replacingOccurrences(of: ",", with: ".")
        return Int((Double(normalized) ?? 0.0) * 100)
    }

    private static func formatCents(_ amount: Int) -> String {
        String(format: "%.2f", Double(amount) / 100.0)
    }

    private static func parseDate(_ str: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
