# KaiToDo — Architecture

> Family shared to-do lists for iOS. MVVM + Services, SwiftUI, CloudKit.

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        VIEWS LAYER                          │
│                                                             │
│  KaiToDoApp → ContentView                                   │
│       │                                                     │
│       ├── Onboarding: NicknameSetupView, OnboardingView     │
│       │                                                     │
│       └── Main App:                                         │
│            HomeView (list grid + FAB)                       │
│              └── ListCard                                   │
│            ListView (tasks + sharing)                       │
│              ├── TaskRow                                    │
│              ├── ShareListSheet                             │
│              ├── JoinListSheet                              │
│              ├── FamilyProgressSheet                        │
│              └── ConfettiView                               │
│            SettingsView                                     │
└────────────────────┬────────────────────────────────────────┘
                     │  @Environment injection
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     VIEWMODELS LAYER                        │
│                                                             │
│  ListsViewModel (@Observable)    UserViewModel (@Observable)│
│  ─────────────────────────────   ────────────────────────── │
│  lists: [TodoList]               profile: UserProfile?      │
│  showingConfetti: Bool           isOnboarding: Bool         │
│  lastCompletedTaskID: UUID       isLoggedIn: Bool           │
│                                                             │
│  • List/Task CRUD                • Profile create/load      │
│  • Invite code generation        • Onboarding state         │
│  • Participant management        • Device token mgmt        │
│  • Confetti trigger              • Logout                   │
│  • Family stats                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                       MODELS LAYER                          │
│                                                             │
│  TodoList              TodoTask              UserProfile     │
│  ───────────────       ──────────────────    ─────────────  │
│  id: UUID              id: UUID              userID: String  │
│  name: String          text: String          nickname: String│
│  color: String (hex)   isCompleted: Bool     deviceToken: ? │
│  tasks: [TodoTask]     completedBy: String?  createdAt: Date │
│  isShared: Bool        completedByName: ?                   │
│  shareType: ShareType  completedAt: Date?    Participant     │
│  participants: [...]   createdAt: Date       ──────────────  │
│  inviteCode: String?   modifiedAt: Date      id: String      │
│  cloudRecordID: ?                            name: String    │
│                        ShareType             joinedAt: Date  │
│                        .local / .owned                       │
│                        .participant                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     SERVICES LAYER                          │
│                                                             │
│  StorageService (singleton, @Observable)                    │
│  ──────────────────────────────────────                     │
│  saveLists() / loadLists()                                  │
│  saveProfile() / loadProfile() / clearAll()                 │
│                                                             │
│  NotificationService (singleton, @Observable)               │
│  ─────────────────────────────────────────────              │
│  requestAuthorization() / registerForRemoteNotifications()  │
│  handleDeviceToken() / scheduleLocalNotification()          │
│  handleNotification() → posts to NotificationCenter         │
│                                                             │
│  CloudKitService (actor — thread-safe) [OPTIONAL]           │
│  ────────────────────────────────────                       │
│  See CloudKit flow below ↓                                  │
└──────────┬──────────────────────────┬───────────────────────┘
           │                          │
           ▼                          ▼
┌─────────────────┐        ┌──────────────────────────────────┐
│   UserDefaults  │        │         Apple CloudKit           │
│  (JSON encoded) │        │  iCloud.com.kaitodo.app          │
│                 │        │                                  │
│ kaitodo.lists   │        │  Public DB:                      │
│ kaitodo.profile │        │   SharedList, Invitation         │
│                 │        │   UserProfile (nicknames)        │
└─────────────────┘        │                                  │
                           │  Private DB:                     │
                           │   SharedTask (per user)          │
                           └──────────────────────────────────┘
```

---

## CloudKit / Sharing Flow

```
User taps Share on a list
         │
         ▼
ListsViewModel.shareList()
         │
         ▼
CloudKitService.saveSharedList()  ──►  Public DB: SharedList record
         │                              + inviteCode (6-char)
         ▼
CloudKitService.createInvitation() ──► Public DB: Invitation record
         │
         ▼
ShareListSheet shows invite code

─────────────────────────────────────

Friend enters invite code in JoinListSheet
         │
         ▼
CloudKitService.findInvitation(code)
         │
         ▼
CloudKitService.fetchSharedList(byInviteCode)
         │
         ▼
CloudKitService.addParticipant()
         │
         ▼
List added to friend's device (local + linked to cloud record)

─────────────────────────────────────

Real-time sync (CloudKit Subscriptions)
         │
         ├── SharedList changed  → update list metadata
         └── SharedTask changed  → update task state
                   │
                   ▼
         NotificationCenter post
                   │
                   ▼
         ListsViewModel refreshes UI
```

---

## Dependency Injection

```
KaiToDoApp
  @State listsViewModel = ListsViewModel()   ← loads from StorageService on init
  @State userViewModel  = UserViewModel()    ← loads from StorageService on init
       │
       └── ContentView
              .environment(listsViewModel)
              .environment(userViewModel)
                    │
                    └── All child views access via @Environment
```

---

## Key Files

| Layer | File | Role |
|-------|------|------|
| Entry | `KaiToDoApp.swift` | Bootstrap, color palette, DI |
| Router | `ContentView.swift` | Onboarding vs. main app |
| ViewModel | `ViewModels/ListsViewModel.swift` | All list/task state |
| ViewModel | `ViewModels/UserViewModel.swift` | User profile state |
| Model | `Models/TodoList.swift` | List + Participant structs |
| Model | `Models/TodoTask.swift` | Task with attribution |
| Model | `Models/UserProfile.swift` | User identity |
| Service | `Services/StorageService.swift` | UserDefaults persistence |
| Service | `Services/CloudKitService.swift` | Sharing + real-time sync |
| Service | `Services/NotificationService.swift` | Push + local notifications |
| View | `Views/HomeView.swift` | Dashboard (grid + FAB) |
| View | `Views/ListView.swift` | Task list + sharing |
| View | `Views/ConfettiView.swift` | Completion celebration |

---

## Architecture Decisions

| Decision | Why |
|----------|-----|
| `@Observable` ViewModels | Modern SwiftUI (iOS 17+), no manual `objectWillChange` |
| UserDefaults for local storage | Small dataset, no CoreData complexity needed |
| CloudKit (not custom backend) | Native Apple, free tier, no server to maintain |
| `actor` for CloudKitService | Thread-safe async CloudKit calls |
| Invite codes (not CKShare) | Simpler UX than native CloudKit sharing sheets |
| Participant attribution on tasks | Family accountability — who did what |
