import SwiftUI

struct MacBudgetView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: BudgetViewModel?

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
            ToolbarItem(placement: .primaryAction) {
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
            set: { _ in vm.toggleExpansion(group.id) }
        )) {
            VStack(spacing: 8) {
                ForEach(group.categories ?? [], id: \.id) { category in
                    CategoryRow(category: category, currencyCode: currencyCode)
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
    let currencyCode: String

    var body: some View {
        let spent = abs(category.spent ?? 0)
        let budgeted = category.budgeted ?? 0
        let progress = budgeted > 0 ? min(Double(spent) / Double(budgeted), 1.0) : 0.0

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category.name)
                    .font(.body)
                Spacer()
                MoneyText(
                    amount: category.balance ?? 0,
                    currencyCode: currencyCode
                )
                .foregroundStyle((category.balance ?? 0) < 0 ? .red : .primary)
            }
            ProgressView(value: progress)
                .tint(progress > 0.85 ? .red : .accentColor)
            HStack {
                Text("Spent: \(CurrencyFormatter.shared.format(spent, currencyCode: currencyCode))")
                Spacer()
                Text("Budgeted: \(CurrencyFormatter.shared.format(budgeted, currencyCode: currencyCode))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
