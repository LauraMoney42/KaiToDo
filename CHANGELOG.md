# Kai To Do — Changelog

## 2026-03-02 — Sync Improvements (3 Phases)

### Phase 1: Task Order Sync (Fractional Indexing)
- Added `sortOrder: Double?` to TodoTask for synced ordering across devices
- Tasks sorted by sortOrder after sync merge — reorder on one device propagates to others
- Fractional indexing: midpoint between neighbors on move, re-normalize on precision exhaustion
- Backward compatible: existing tasks without sortOrder auto-normalized on load
- Files: `Models/TodoTask.swift`, `Services/CloudKitService.swift`, `ViewModels/ListsViewModel.swift`

### Phase 2: CKShare + Private DB (Zone-Level Sharing)
- Migrated from public DB to private DB with CKShare for shared lists
- Each shared list gets its own custom zone (`KaiList-{UUID}`)
- CKShare grants all participants readWrite — eliminates replacement record workaround
- Invite code UX preserved (codes still work, CKShare is a backend detail)
- Dual-path sync: `isMigratedToPrivateDB` flag routes to correct code path
- Invitation records stay in public DB for invite code lookup
- Added CKDatabaseSubscription for private + shared DB push notifications
- Files: `Models/TodoList.swift`, `Services/CloudKitService.swift`, `Services/StorageService.swift`, `Views/ShareListSheet.swift`, `Views/JoinListSheet.swift`, `KaiToDoApp.swift`, `ViewModels/ListsViewModel.swift`

### Phase 3: Delta Sync (Change Tokens)
- Added CKFetchRecordZoneChangesOperation with persisted change tokens
- First sync: full fetch + stores token; subsequent syncs: delta only
- Handles token expiry gracefully (clears token, falls back to full fetch)
- CKFetchDatabaseChangesOperation to identify which zones changed
- Change tokens persisted in UserDefaults via StorageService
- Files: `Services/CloudKitService.swift`, `Services/StorageService.swift`, `ViewModels/ListsViewModel.swift`
