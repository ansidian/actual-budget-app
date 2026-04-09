import Foundation
import Combine

final class AppState: ObservableObject {
    // --- NEW: Theme Management ---
    enum Theme: String, CaseIterable, Identifiable {
        case Dark = "Dark"
        case amoledDark = "Dark (AMOLED)"
        case systemLight = "System Light"
        var id: String { self.rawValue }
    }
    
    @Published var currentTheme: Theme {    
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: Keys.currentTheme) }
    }
    
    // Other properties...
    @Published var baseURLString: String {
        didSet {
            UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL)
            AppLogger.shared.updateRedactionBaseURL(baseURLString)
        }
    }
    @Published var apiKey: String {
        didSet {
            #if os(macOS)
            KeychainStorage.write(apiKey, for: Keys.apiKey)
            #else
            UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
            #endif
        }
    }
    @Published var syncId: String {
        didSet { UserDefaults.standard.set(syncId, forKey: Keys.syncId) }
    }
    @Published var budgetEncryptionPassword: String {
        didSet {
            #if os(macOS)
            KeychainStorage.write(budgetEncryptionPassword, for: Keys.budgetEncryptionPassword)
            #else
            UserDefaults.standard.set(budgetEncryptionPassword, forKey: Keys.budgetEncryptionPassword)
            #endif
        }
    }
    @Published var isDemoMode: Bool {
        didSet { UserDefaults.standard.set(isDemoMode, forKey: Keys.isDemoMode) }
    }
    @Published var currencyCode: String {
        didSet { UserDefaults.standard.set(currencyCode, forKey: Keys.currencyCode) }
    }

    var isConfigured: Bool { isDemoMode || (!baseURLString.isEmpty && !apiKey.isEmpty && !syncId.isEmpty) }

    init() {
        self.baseURLString = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        self.syncId = UserDefaults.standard.string(forKey: Keys.syncId) ?? ""
        self.isDemoMode = UserDefaults.standard.bool(forKey: Keys.isDemoMode)
        self.currencyCode = UserDefaults.standard.string(forKey: Keys.currencyCode) ?? Locale.current.currency?.identifier ?? "USD"

        #if os(macOS)
        // Prefer Keychain on macOS. Migrate any legacy UserDefaults values
        // into the Keychain on first launch and remove the plaintext copy.
        if let stored = KeychainStorage.read(Keys.apiKey) {
            self.apiKey = stored
        } else if let legacy = UserDefaults.standard.string(forKey: Keys.apiKey), !legacy.isEmpty {
            self.apiKey = legacy
            KeychainStorage.write(legacy, for: Keys.apiKey)
            UserDefaults.standard.removeObject(forKey: Keys.apiKey)
        } else {
            self.apiKey = ""
        }

        if let stored = KeychainStorage.read(Keys.budgetEncryptionPassword) {
            self.budgetEncryptionPassword = stored
        } else if let legacy = UserDefaults.standard.string(forKey: Keys.budgetEncryptionPassword), !legacy.isEmpty {
            self.budgetEncryptionPassword = legacy
            KeychainStorage.write(legacy, for: Keys.budgetEncryptionPassword)
            UserDefaults.standard.removeObject(forKey: Keys.budgetEncryptionPassword)
        } else {
            self.budgetEncryptionPassword = ""
        }
        #else
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        self.budgetEncryptionPassword = UserDefaults.standard.string(forKey: Keys.budgetEncryptionPassword) ?? ""
        #endif

        let savedTheme = UserDefaults.standard.string(forKey: Keys.currentTheme) ?? ""
        self.currentTheme = Theme(rawValue: savedTheme) ?? .amoledDark
        AppLogger.shared.updateRedactionBaseURL(self.baseURLString)
    }

    func resetConfiguration() {
        baseURLString = ""
        apiKey = ""
        syncId = ""
        budgetEncryptionPassword = ""
    }

    private enum Keys {
        static let baseURL = "ActualBaseURL"
        static let apiKey = "ActualAPIKey"
        static let syncId = "ActualSyncId"
        static let budgetEncryptionPassword = "ActualBudgetEncryptionPassword"
        static let isDemoMode = "ActualIsDemoMode"
        static let currencyCode = "ActualCurrencyCode"
        static let currentTheme = "ActualCurrentTheme" // New key
    }
}