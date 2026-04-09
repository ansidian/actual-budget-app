import SwiftUI

struct MacDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var vm: DashboardViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let vm {
                    metrics(vm: vm)
                    recentSection(vm: vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .toolbar {
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
                vm = DashboardViewModel(appState: appState)
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
    private func metrics(vm: DashboardViewModel) -> some View {
        Text("Overview")
            .font(.largeTitle.weight(.semibold))

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
            metricCard(title: "Spent Today", value: vm.spentToday(), isMoney: true)
            metricCard(title: "Spent This Month", value: vm.spentThisMonth(), isMoney: true)
            metricCard(title: "Spent Last Month", value: vm.spentLastMonth(), isMoney: true)
            metricCard(title: "On-Budget Accounts", value: vm.onBudgetAccounts.count, isMoney: false)
        }
    }

    @ViewBuilder
    private func recentSection(vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.title2.weight(.semibold))

            if vm.recentFive.isEmpty {
                Text("No recent transactions to show.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Table(vm.recentFive) {
                    TableColumn("Date") { tx in Text(tx.date) }
                        .width(min: 90, ideal: 100)
                    TableColumn("Payee") { tx in Text(vm.payeeName(for: tx)) }
                    TableColumn("Category") { tx in
                        Text(tx.category.flatMap { vm.categoriesById[$0] } ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    TableColumn("Amount") { tx in
                        MoneyText(amount: tx.amount, currencyCode: appState.currencyCode, signed: true)
                    }
                    .width(min: 100, ideal: 120)
                }
                .frame(minHeight: 240)
            }
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: Int, isMoney: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isMoney {
                MoneyText(amount: value, currencyCode: appState.currencyCode, emphasis: true)
                    .font(.title2)
            } else {
                Text("\(value)")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
