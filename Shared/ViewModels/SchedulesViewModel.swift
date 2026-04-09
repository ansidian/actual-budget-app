import Foundation
import Observation

/// Owns schedules list state, filtering (upcoming vs. completed), and CRUD.
@MainActor
@Observable
final class SchedulesViewModel {
    enum Filter: String, CaseIterable, Identifiable {
        case upcoming, completed, all
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private let appState: AppState

    var schedules: [Schedule] = []
    var filter: Filter = .upcoming
    var selectedScheduleId: String?
    var isLoading: Bool = false
    var errorMessage: String?
    /// Set when the endpoint 404s — older self-hosted deployments don't support schedules.
    var endpointUnsupported: Bool = false

    init(appState: AppState) {
        self.appState = appState
    }

    var filteredSchedules: [Schedule] {
        switch filter {
        case .upcoming:
            return schedules.filter { !($0.completed ?? false) }
        case .completed:
            return schedules.filter { $0.completed ?? false }
        case .all:
            return schedules
        }
    }

    var selectedSchedule: Schedule? {
        guard let id = selectedScheduleId else { return nil }
        return schedules.first { $0.id == id }
    }

    // MARK: - Loading

    func load() async {
        guard appState.isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try makeClient()
            schedules = try await client.fetchSchedules()
            endpointUnsupported = false
        } catch APIError.unsupportedEndpoint {
            endpointUnsupported = true
            schedules = []
        } catch {
            AppLogger.shared.log(error: error, context: "SchedulesViewModel.load")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    func create(_ input: ScheduleInput) async {
        do {
            let client = try makeClient()
            _ = try await client.createSchedule(input)
            await load()
        } catch {
            AppLogger.shared.log(error: error, context: "SchedulesViewModel.create")
            self.errorMessage = error.localizedDescription
        }
    }

    func update(id: String, _ input: ScheduleInput) async {
        do {
            let client = try makeClient()
            try await client.updateSchedule(id: id, input)
            await load()
        } catch {
            AppLogger.shared.log(error: error, context: "SchedulesViewModel.update")
            self.errorMessage = error.localizedDescription
        }
    }

    func delete(id: String) async {
        do {
            let client = try makeClient()
            try await client.deleteSchedule(id: id)
            schedules.removeAll { $0.id == id }
            if selectedScheduleId == id { selectedScheduleId = nil }
        } catch {
            AppLogger.shared.log(error: error, context: "SchedulesViewModel.delete")
            self.errorMessage = error.localizedDescription
        }
    }

    private func makeClient() throws -> ActualAPIClient {
        try ActualAPIClient(
            baseURLString: appState.baseURLString,
            apiKey: appState.apiKey,
            syncId: appState.syncId,
            budgetEncryptionPassword: appState.budgetEncryptionPassword,
            isDemoMode: appState.isDemoMode
        )
    }
}
