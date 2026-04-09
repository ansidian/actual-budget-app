import SwiftUI

struct MacBudgetView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: BudgetViewModel?
    @State private var showingMonthNotes: Bool = false

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(vm?.monthTitle ?? "Budget")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    Task { await vm?.moveMonth(-1) }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(vm == nil)

                Button {
                    Task { await vm?.moveMonth(+1) }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(vm == nil)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await vm?.loadCurrentMonthNoteIfNeeded()
                        showingMonthNotes = true
                    }
                } label: {
                    let hasNote = !(vm?.currentMonthNote().isEmpty ?? true)
                    Label("Month Notes", systemImage: hasNote ? "note.text" : "note")
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
        .sheet(isPresented: $showingMonthNotes) {
            if let vm {
                NotesEditorSheet(
                    title: "Notes — \(vm.monthTitle)",
                    initialText: vm.currentMonthNote(),
                    onSave: { text in Task { await vm.saveCurrentMonthNote(text) } }
                )
                .frame(width: 480, height: 360)
            }
        }
        .task {
            if vm == nil {
                vm = BudgetViewModel(appState: appState)
                await vm?.load()
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
    private func content(vm: BudgetViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(vm: vm)
                groups(vm: vm)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func header(vm: BudgetViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To Be Budgeted")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            MoneyText(
                amount: vm.budget?.toBudget ?? 0,
                currencyCode: appState.currencyCode,
                emphasis: true
            )
            .font(.largeTitle)

            Divider()

            HStack(spacing: 32) {
                metric("Available", value: vm.budget?.incomeAvailable ?? 0)
                metric("Budgeted", value: vm.budget?.totalBudgeted ?? 0)
                metric("Spent", value: vm.budget?.totalSpent ?? 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func metric(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            MoneyText(amount: value, currencyCode: appState.currencyCode)
                .font(.body)
        }
    }

    @ViewBuilder
    private func groups(vm: BudgetViewModel) -> some View {
        if vm.monthGroups.isEmpty {
            Text("No budget categories found for this month.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            VStack(spacing: 12) {
                ForEach(vm.sortedGroups, id: \.id) { group in
                    GroupSection(group: group, vm: vm, currencyCode: appState.currencyCode)
                }
            }
        }
    }
}

private struct GroupSection: View {
    let group: BudgetMonthCategoryGroup
    let vm: BudgetViewModel
    let currencyCode: String

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { vm.isExpanded(group.id) },
            set: { vm.setExpanded(group.id, $0) }
        )) {
            VStack(spacing: 8) {
                ForEach(group.categories ?? [], id: \.id) { category in
                    CategoryRow(category: category, vm: vm, currencyCode: currencyCode)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                MoneyText(amount: group.balance ?? 0, currencyCode: currencyCode)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CategoryRow: View {
    let category: BudgetMonthCategory
    let vm: BudgetViewModel
    let currencyCode: String
    @State private var showingNotes: Bool = false
    @State private var noteDraft: String = ""

    private enum RowState {
        case income(received: Int)
        case zeroActivity
        case unbudgeted(spent: Int)
        case overspent(spent: Int, budgeted: Int, overflow: Int)
        case onTrack(spent: Int, budgeted: Int, balance: Int)
    }

    private var rowState: RowState {
        // Income categories in Actual expose their monthly total via a
        // `received` field. Older data or the HTTP API wrapper may instead
        // deliver it as a negative `spent` value — fall back to that if
        // `received` is absent. Finally, `balance` tends to match the
        // monthly total for income categories and is used as a last resort.
        if category.is_income == true {
            let candidate: Int
            if let r = category.received {
                candidate = r
            } else if let s = category.spent, s != 0 {
                candidate = s
            } else {
                candidate = category.balance ?? 0
            }
            return .income(received: abs(candidate))
        }
        let spent = abs(category.spent ?? 0)
        let budgeted = category.budgeted ?? 0
        let balance = category.balance ?? (budgeted - spent)

        if spent == 0 && budgeted == 0 {
            return .zeroActivity
        }
        if budgeted == 0 && spent > 0 {
            return .unbudgeted(spent: spent)
        }
        if balance < 0 {
            return .overspent(spent: spent, budgeted: budgeted, overflow: -balance)
        }
        return .onTrack(spent: spent, budgeted: budgeted, balance: balance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            progressSection
            footer
        }
        .padding(.vertical, 4)
        .task {
            await vm.loadCategoryNotesIfNeeded(category.id)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(category.name)
                .font(.body)
            Button {
                noteDraft = vm.categoryNote(category.id)
                showingNotes = true
            } label: {
                if vm.categoryHasNotes(category.id) {
                    Image(systemName: "note.text")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "note")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .help(vm.categoryHasNotes(category.id) ? "Edit notes" : "Add notes")
            .popover(isPresented: $showingNotes, arrowEdge: .trailing) {
                NotesEditor(
                    title: category.name,
                    text: $noteDraft,
                    onSave: {
                        let draft = noteDraft
                        Task { await vm.saveCategoryNotes(category.id, text: draft) }
                        showingNotes = false
                    },
                    onCancel: { showingNotes = false }
                )
                .frame(width: 360, height: 280)
            }
            Spacer()
            switch rowState {
            case .income(let received):
                MoneyText(amount: received, currencyCode: currencyCode)
                    .foregroundStyle(.green)
            case .zeroActivity:
                MoneyText(amount: 0, currencyCode: currencyCode)
                    .foregroundStyle(.secondary)
            case .unbudgeted(let spent):
                MoneyText(amount: -spent, currencyCode: currencyCode)
                    .foregroundStyle(.orange)
            case .overspent(_, _, let overflow):
                MoneyText(amount: -overflow, currencyCode: currencyCode)
                    .foregroundStyle(.red)
            case .onTrack(_, _, let balance):
                MoneyText(amount: balance, currencyCode: currencyCode)
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        switch rowState {
        case .income, .zeroActivity:
            EmptyView()
        case .unbudgeted:
            ProgressView(value: 1.0)
                .tint(.orange)
        case .overspent:
            ProgressView(value: 1.0)
                .tint(.red)
        case .onTrack(let spent, let budgeted, _):
            let progress = budgeted > 0 ? min(Double(spent) / Double(budgeted), 1.0) : 0.0
            ProgressView(value: progress)
                .tint(.accentColor)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch rowState {
        case .income(let received):
            HStack {
                Text("Received: \(CurrencyFormatter.shared.format(received, currencyCode: currencyCode))")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .zeroActivity:
            EmptyView()
        case .unbudgeted(let spent):
            HStack {
                Text("Spent: \(CurrencyFormatter.shared.format(spent, currencyCode: currencyCode))")
                Spacer()
                Text("No budget")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .overspent(let spent, let budgeted, _):
            HStack {
                Text("Spent: \(CurrencyFormatter.shared.format(spent, currencyCode: currencyCode))")
                Spacer()
                Text("Budgeted: \(CurrencyFormatter.shared.format(budgeted, currencyCode: currencyCode))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .onTrack(let spent, let budgeted, _):
            HStack {
                Text("Spent: \(CurrencyFormatter.shared.format(spent, currencyCode: currencyCode))")
                Spacer()
                Text("Budgeted: \(CurrencyFormatter.shared.format(budgeted, currencyCode: currencyCode))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
