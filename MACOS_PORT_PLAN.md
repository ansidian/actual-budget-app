# Actual Budget — macOS Native App Port Plan

## Context

This repo (`BearTS/actual-budget-app`) is a native iOS SwiftUI client for Actual Budget. The cwd is the cloned repo root. The goal is to add a macOS target that reuses as much existing code as possible, producing a proper Mac-native app (sidebar navigation, multi-column layout, keyboard shortcuts, menu bar) — not just a Catalyst port or scaled-up phone UI.

The existing codebase is ~2,940 lines of Swift across 31 files. It talks to the `actual-http-api` REST wrapper (not the Actual server directly). There are zero UIKit dependencies — everything is pure SwiftUI — which makes this viable.

License permits personal use and modification.

## Existing Code Map

```
iOSApp/
├── App/
│   ├── ActualAccountsApp.swift        (12 lines)  — @main entry, WindowGroup + AppState
│   └── AppIntents.swift               (41 lines)  — Siri/Shortcuts (iOS-only, skip)
├── Features/
│   ├── RootView.swift                 (56 lines)  — TabView (Dashboard/Accounts/Budget/Settings)
│   ├── Dashboard/DashboardView.swift  (339 lines) — overview metrics + recent transactions
│   ├── Accounts/AccountsView.swift    (248 lines) — account list, balances, create/close
│   ├── Budget/BudgetView.swift        (190 lines) — monthly budget with category groups
│   ├── Transactions/
│   │   ├── AllTransactionsView.swift   (225 lines) — full transaction list across accounts
│   │   ├── TransactionsView.swift      (192 lines) — per-account transaction list
│   │   ├── TransactionEditor.swift     (240 lines) — create/edit transaction form
│   │   └── SheetType.swift            (17 lines)  — enum for sheet presentation
│   ├── Onboarding/OnboardingView.swift(120 lines) — server connection setup
│   └── Settings/
│       ├── SettingsView.swift         (114 lines) — config, theme, currency, demo toggle
│       └── LogsView.swift             (60 lines)  — debug log viewer
├── Networking/
│   ├── ActualAPIClient.swift          (250 lines) — async/await REST client (FULL CRUD)
│   ├── APIEndpoints.swift             (34 lines)  — URL construction for all endpoints
│   └── DemoDataService.swift          (82 lines)  — generates fake data for demo mode
├── Shared/
│   ├── APIModels.swift                (101 lines) — Codable structs: Account, Transaction, Category, Payee, BudgetMonth, etc.
│   ├── AppState.swift                 (70 lines)  — ObservableObject with @Published config (baseURL, apiKey, syncId, etc.)
│   ├── AppTheme.swift                 (18 lines)  — colors + font definitions
│   ├── AppBackground.swift            (15 lines)  — theme-aware background view
│   ├── CurrencyFormatter.swift        (33 lines)  — Int-cents → formatted currency string
│   ├── AppLogger.swift                (100 lines) — structured logging
│   ├── NetworkLogger.swift            (23 lines)  — HTTP error logging
│   └── SharedDataManager.swift        (35 lines)  — WidgetKit shared data (iOS-only)
├── UI/
│   ├── GlassCard.swift                (22 lines)  — frosted glass card component
│   ├── GlassTextFieldStyle.swift      (15 lines)  — matching text field style
│   ├── LiquidBackground.swift         (11 lines)  — gradient background
│   └── TransactionRow.swift           (82 lines)  — transaction list row with swipe actions
└── SummaryWidget/                     (3 files)   — iOS WidgetKit extension (skip entirely)
```

## Architecture Notes

- **No ViewModel layer.** Views directly create `ActualAPIClient` instances and hold `@State` for data. Every feature view has its own `private func client() throws -> ActualAPIClient` that constructs a new client from `AppState`. This is the biggest refactor opportunity.
- **API client is clean and reusable.** `ActualAPIClient` is pure Foundation networking with async/await. Zero platform-specific code.
- **All models are plain Codable structs.** `APIModels.swift` is fully portable.
- **Amounts are Int cents.** The API returns amounts in cents; `CurrencyFormatter` handles display.
- **Auth is simple.** API key in `x-api-key` header, sync ID in URL path, optional encryption password header.

## iOS-Specific Code That Won't Port Directly

| File/Pattern | Issue | Action |
|---|---|---|
| `RootView.swift` — `TabView` | Phone-style tabs | Replace with `NavigationSplitView` + sidebar |
| `AccountsView.swift` — `.navigationBarTrailing` | iOS toolbar placement | Use `.toolbar` with macOS-compatible placement |
| `OnboardingView.swift` — `.keyboardType(.URL)`, `.textInputAutocapitalization(.never)` | iOS-only modifiers | Remove (no-op on macOS anyway, but cleaner without) |
| `TransactionEditor.swift` — `.keyboardType(.decimalPad)` | iOS keyboard type | Remove |
| `AccountsView.swift` — `.refreshable` | Pull-to-refresh (iOS) | Replace with toolbar refresh button or Cmd+R |
| `AccountsView.swift` — `.presentationDetents([.height(250)])` | iOS sheet sizing | Use `.frame()` on macOS or a popover |
| `AppBackground.swift` — `Color(.systemGroupedBackground)` | UIColor reference | Use `Color(nsColor: .windowBackgroundColor)` or similar |
| `SharedDataManager.swift` | WidgetKit data sharing | Skip for macOS |
| `AppIntents.swift` | Siri Shortcuts | Skip for macOS |
| `SummaryWidget/` (3 files) | iOS WidgetKit | Skip entirely |

## The Plan

### Phase 1: Project Setup & Shared Code Extraction

1. **Create a new macOS app target** alongside the existing iOS target. Use `project.yml` (the repo uses XcodeGen) or create a new `Package.swift` / Xcode project under a `macOSApp/` directory. Minimum deployment target: macOS 14.0 (Sonoma) for `@Observable` support if we migrate to that, or macOS 13.0 if we stick with `ObservableObject`.

2. **Create a `Shared/` directory at the repo root** (or use a Swift Package) and move these files into it — they compile on both platforms with zero changes:
   - `Networking/ActualAPIClient.swift`
   - `Networking/APIEndpoints.swift`
   - `Networking/DemoDataService.swift`
   - `Shared/APIModels.swift`
   - `Shared/AppState.swift`
   - `Shared/CurrencyFormatter.swift`
   - `Shared/AppLogger.swift`
   - `Shared/NetworkLogger.swift`
   - `Shared/AppTheme.swift` (minor tweaks for macOS font sizes)

3. **Create a shared ViewModel layer** (this doesn't exist yet and is the key refactor). Extract the data-fetching and business logic out of the views:
   - `AccountsViewModel` — fetches accounts, balances, handles create/delete/close/reopen
   - `TransactionsViewModel` — fetches transactions for an account or all accounts, handles CRUD
   - `BudgetViewModel` — fetches budget month data and category groups
   - `DashboardViewModel` — aggregates spending metrics (spentToday, spentThisMonth, spentLastMonth)

   Each ViewModel should be an `@Observable` class (macOS 14+) or `ObservableObject` that takes an `ActualAPIClient` and exposes `@Published` state. This eliminates the repeated `private func client()` pattern in every view and makes the logic testable and platform-independent.

### Phase 2: macOS App Shell

4. **Create the macOS entry point** (`ActualBudgetMacApp.swift`):
   ```swift
   @main
   struct ActualBudgetMacApp: App {
       @StateObject private var appState = AppState()

       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(appState)
           }
           .commands {
               // Cmd+R to refresh, Cmd+N new transaction, etc.
           }
           Settings {
               SettingsView()
                   .environmentObject(appState)
           }
       }
   }
   ```

5. **Build the main layout** as a three-column `NavigationSplitView`:
   - **Sidebar**: Navigation items — Dashboard, Accounts (with sub-items for each account), Budget, All Transactions
   - **Content column**: The selected feature's list view (account list, transaction list, budget categories)
   - **Detail column**: Detail/editor for the selected item (transaction detail, budget category detail)

   ```
   ┌──────────┬─────────────────────┬─────────────────────┐
   │ Sidebar  │ Content             │ Detail              │
   │          │                     │                     │
   │ Dashboard│ [Transaction list]  │ [Transaction editor]│
   │ Accounts │                     │                     │
   │  ├ Chase │                     │                     │
   │  ├ Savings                     │                     │
   │ Budget   │                     │                     │
   │ All Txns │                     │                     │
   └──────────┴─────────────────────┴─────────────────────┘
   ```

6. **Onboarding**: Instead of a full-screen onboarding flow, use a modal `Sheet` on first launch or put config into the Settings scene (accessed via Cmd+,). The existing `OnboardingView` can mostly be reused with layout adjustments — remove iOS keyboard modifiers, use `NSWindow`-appropriate sizing.

### Phase 3: Port Feature Views

For each feature, create a macOS-specific view that uses the shared ViewModel:

7. **DashboardView (macOS)**:
   - Use the existing metrics logic (spentToday, spentThisMonth, etc.) from the extracted `DashboardViewModel`
   - Layout: single-column scrollable view with metric cards in an `HStack`/`LazyVGrid` and a recent transactions table below
   - Use `Table` (macOS native) instead of `List` + `ForEach` for the transactions section — gives you sortable columns for free

8. **AccountsView (macOS)**:
   - Sidebar already shows accounts, so this becomes the content when "Accounts" group is selected
   - Show account cards in a `LazyVGrid` or use a `Table` with columns: Name, Type, Balance, Status
   - Replace `.refreshable` with a toolbar refresh button

9. **TransactionsView (macOS)**:
   - Use `Table` with sortable columns: Date, Payee, Category, Amount, Account, Cleared
   - Support multi-selection for bulk operations
   - Inline editing or detail panel for transaction editing (instead of sheets)
   - Toolbar: filter controls, search field, "Add Transaction" button
   - Keyboard: Delete key to delete, Enter to edit, Cmd+N to add

10. **BudgetView (macOS)**:
    - Keep the existing DisclosureGroup pattern — it works well on macOS
    - Use a wider layout, show budgeted/spent/balance columns side by side
    - Month navigation via toolbar buttons (existing chevron pattern works)

11. **TransactionEditor (macOS)**:
    - Reuse the existing form logic almost entirely
    - Present in the detail column or as a sheet (not a full-screen modal)
    - Remove `.keyboardType(.decimalPad)` — not available on macOS
    - The `buildTransaction()` and `save()` functions port directly

12. **SettingsView (macOS)**:
    - Move into a proper `Settings` scene (Cmd+, to access)
    - Use `TabView` with `.tabViewStyle(.grouped)` for macOS settings tabs (Connection, Appearance, Advanced)
    - Rework theme options — replace "AMOLED Dark" with standard macOS appearance (respects system dark mode)

### Phase 4: macOS Polish

13. **AppTheme adjustments**:
    - Reduce font sizes slightly (macOS renders at higher density than iOS)
    - Replace `Color(.systemGroupedBackground)` with `Color(nsColor: .windowBackgroundColor)` 
    - Consider respecting `.preferredColorScheme` from system rather than custom theme enum
    - Update `GlassCard` — the heavy glassmorphism look may feel out of place on macOS; consider using `.background(.regularMaterial)` or just subtle rounded rects

14. **Keyboard shortcuts**:
    - `Cmd+N` — new transaction
    - `Cmd+R` — refresh current view
    - `Cmd+,` — settings
    - `Delete` — delete selected transaction(s)
    - `Cmd+1/2/3/4` — switch sidebar sections
    - Arrow keys for table navigation

15. **Menu bar**:
    - Add standard Edit, View menus
    - View menu: toggle sidebar, switch sections
    - Optional: menu bar extra (status item) showing today's spending

16. **Window management**:
    - Set minimum window size (~800×500)
    - Remember window position/size via `@SceneStorage`
    - Support multiple windows if useful (e.g., open a budget month in a separate window)

17. **Keychain storage**: Currently secrets (API key, encryption password) are stored in plain `UserDefaults`. On macOS, migrate these to Keychain using `Security.framework`. This is a nice-to-have but important for a proper Mac app.

### Phase 5: Testing & Cleanup

18. **Test with demo mode first** — the existing `DemoDataService` generates fake data, so you can test the full UI without a running Actual server.

19. **Test with a real Actual server** — make sure you have `actual-http-api` running and pointed at your Actual instance. Verify all CRUD operations work.

20. **Clean up conditional compilation** — use `#if os(macOS)` / `#if os(iOS)` for the small number of platform-specific differences rather than duplicating entire files where possible.

## File Structure (Target State)

```
actual-budget-app/
├── Shared/                          ← NEW: cross-platform code
│   ├── Networking/
│   │   ├── ActualAPIClient.swift    (moved from iOSApp/)
│   │   ├── APIEndpoints.swift       (moved)
│   │   └── DemoDataService.swift    (moved)
│   ├── Models/
│   │   └── APIModels.swift          (moved)
│   ├── ViewModels/                  ← NEW: extracted from views
│   │   ├── AccountsViewModel.swift
│   │   ├── TransactionsViewModel.swift
│   │   ├── BudgetViewModel.swift
│   │   └── DashboardViewModel.swift
│   ├── State/
│   │   └── AppState.swift           (moved)
│   └── Utilities/
│       ├── AppTheme.swift           (moved, with #if os() tweaks)
│       ├── CurrencyFormatter.swift  (moved)
│       ├── AppLogger.swift          (moved)
│       └── NetworkLogger.swift      (moved)
├── iOSApp/                          ← existing iOS app (unchanged or updated to use Shared/)
│   └── ...
├── macOSApp/                        ← NEW
│   ├── ActualBudgetMacApp.swift     — @main entry with WindowGroup + Settings scene
│   ├── ContentView.swift            — NavigationSplitView shell
│   ├── Sidebar.swift                — sidebar navigation
│   ├── Views/
│   │   ├── DashboardView.swift      — macOS dashboard layout
│   │   ├── AccountsView.swift       — macOS accounts grid/table
│   │   ├── TransactionsTableView.swift — macOS Table-based transactions
│   │   ├── BudgetView.swift         — macOS budget layout
│   │   ├── TransactionEditor.swift  — macOS transaction form
│   │   ├── OnboardingSheet.swift    — macOS onboarding modal
│   │   └── SettingsView.swift       — macOS Settings scene
│   ├── Components/
│   │   ├── MetricCard.swift
│   │   └── TransactionRow.swift
│   └── Resources/
│       └── Assets.xcassets
└── ...
```

## Suggested Order of Operations

Start here — each step should leave you with something that compiles and runs:

1. Create `macOSApp/` directory and a minimal `ActualBudgetMacApp.swift` that shows "Hello World" in a `WindowGroup`. Verify it builds for macOS.
2. Copy the `Shared/` files (Networking, Models, AppState, utilities) into the macOS target's sources. Verify it compiles — it should, since there's no platform-specific code.
3. Build the `ContentView` with `NavigationSplitView` and a hardcoded sidebar. Wire up `AppState` as environment object. Add the onboarding check.
4. Port `DashboardView` first (it's the most self-contained). Get it loading and displaying data from demo mode.
5. Port `AccountsView` — accounts in the sidebar or content pane, with balances.
6. Port `TransactionsView` using `Table` — this is where macOS really shines over iOS.
7. Port `BudgetView` — mostly works as-is with layout tweaks.
8. Port `TransactionEditor` — present as sheet or detail pane.
9. Add Settings scene, keyboard shortcuts, menu bar commands.
10. Polish: window sizing, Keychain migration, theme refinements.

## Key Dependencies

- **actual-http-api** (`jhonderson/actual-http-api`) — the REST wrapper the app talks to. Must be running and accessible from your Mac. The app does NOT talk to the Actual server directly.
- **Xcode 15+** and **macOS 14+ SDK** (for modern SwiftUI features like `Observable`)
- **XcodeGen** (optional) — the iOS project uses `project.yml` / XcodeGen. You can either extend it or create a standalone Xcode project for the macOS target.

## Notes

- The ViewModel extraction (Phase 1 step 3) is the highest-leverage refactor. It's optional if you just want to get something running fast — you can copy-paste the views and adapt them directly — but it'll pay dividends immediately if you want to keep both platforms in sync.
- If you want to skip the ViewModel refactor initially, you can just copy each iOS view, strip the iOS-only modifiers, swap `TabView` → `NavigationSplitView`, and it'll basically work. The views are self-contained enough.
- The `swagger.json` in the repo root documents the full actual-http-api spec — useful reference for adding new API endpoints the iOS app doesn't cover yet.
