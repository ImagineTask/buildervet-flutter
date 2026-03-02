# BuilderVet

A renovation platform for managing tasks, projects, contractors, and quotes. Built with Flutter for iOS and Android.

## Getting Started

### Prerequisites

- Flutter SDK (>= 3.2.0)
- Xcode (for iOS) or Android Studio (for Android)
- A Mac is required for iOS builds

### Setup

```bash
git clone https://github.com/ImagineTask/buildervet-flutter.git
cd buildervet-flutter
bash setup.sh    # generates platform folders (run once)
flutter run
```

### Manual Setup (if not using setup.sh)

```bash
flutter create buildervet_temp --org com.buildervet
# Copy android/, ios/ folders from buildervet_temp into this project
# Then delete buildervet_temp
flutter pub get
flutter run
```

---

## Architecture Overview

The app follows a **feature-first** architecture with a **repository pattern** for clean separation of concerns. The core design principle is that everything is a **Task** — a project is simply a task with `taskType: project`. This flat data model keeps the backend shallow and extensible.

Currently running on **mock data** (JSON). When the backend is ready, swap one line in `service_locator.dart` and the entire UI stays untouched.

### State Management

- **Riverpod** for reactive state management
- Providers for data fetching, selection state, and search

### Navigation

- **GoRouter** with a `ShellRoute` for bottom navigation
- Action screens and detail screens push on top of the shell

### Action System

Actions are the core interaction model. Each task carries an `actionSpace` — a list of action keys that determine what the user can do. Actions are resolved through a **registry + router** pattern:

- **Action Registry** — single source of truth for all system action configs (icon, colour, display mode, AI metadata)
- **Action Router** — reads registry or action type, opens the correct screen/sheet/webview
- **Three display modes** — full screen (complex actions), bottom sheet (quick actions), web view (external services)
- **Project actions** — projects have 5 dedicated actions (Detail, Quote, Schedule, Photo, Invoice) that each open a reusable task list, then drill into task-specific screens
- **Custom user actions** — users can create their own actions (web links, phone calls, notes) without any code changes
- **AI-ready** — the registry provides structured metadata (priority, requirements, descriptions) that AI agents can use to recommend and execute actions

---

## File-by-File Documentation

### Entry Point

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point. Wraps the app in Riverpod's `ProviderScope` and launches `RenovationApp`. |
| `lib/app.dart` | Root `MaterialApp.router` widget. Configures the theme (light/dark), GoRouter, and debug banner. |

---

### Core (`lib/core/`)

Foundation layer — non-UI code used across the entire app.

#### Config (`lib/core/config/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `app_config.dart` | Environment configuration. | `useMockData` flag (set to `false` when backend is ready), `apiBaseUrl` for the real API, app name and version. |
| `constants.dart` | App-wide constant values. | Mock data asset path, default page size, animation and snackbar durations. |
| `feature_flags.dart` | Runtime feature toggles. | Toggle chat, AI pricing, calendar, alerts, and network features on/off without code changes. |

#### Dependency Injection (`lib/core/di/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `service_locator.dart` | Central provider setup for dependency injection. | Provides `TaskRepository` — returns `MockTaskRepository` when `useMockData` is true, swap to `ApiTaskRepository` when backend is ready. **This is the single place to switch from mock to real data.** |

#### Routing (`lib/core/routing/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `app_router.dart` | GoRouter configuration with all routes. | `ShellRoute` wraps the 5 bottom nav tabs. Task detail screen pushes on top. "See all" routes for full list views. Project action routes (`/actions/project-tasks/:projectId/detail|quote|schedule|invoice`). Task action routes (`/actions/task-quote/:taskId`, etc.). Project photo route. Generic web view route. |
| `route_names.dart` | Route name constants. | `RouteNames.home`, `RouteNames.taskDetail`, `RouteNames.seeAllProjects`, `RouteNames.seeAllTasks`. |

#### Theme (`lib/core/theme/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `app_theme.dart` | `ThemeData` for light and dark modes. | Material 3, custom card theme (`CardThemeData`), bottom nav bar styling, input decoration theme. |
| `app_colors.dart` | Colour palette constants. | Brand colours (primary blue, secondary purple, accent amber), background/surface colours, text colours (primary, secondary, tertiary), border colour, status colours (draft grey, pending amber, in-progress blue, completed green, cancelled red). |
| `app_typography.dart` | Text style definitions. | Headline (large/medium/small), title (large/medium), body (large/medium/small), label (large/small) — all with consistent sizing and weights. |
| `app_spacing.dart` | Spacing and border radius constants. | Padding/margin scale: `xs(4)`, `sm(8)`, `md(16)`, `lg(24)`, `xl(32)`, `xxl(48)`. Border radius scale: `radiusXs(4)` through `radiusFull(999)`. |

#### Utilities (`lib/core/utils/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `date_utils.dart` | Date formatting helpers. | `formatDate`, `formatDateTime`, `formatShortDate`, `formatTime`, `timeAgo` (relative time like "3h ago"), `dateRange` (e.g. "01 Mar – 15 Jun"). |
| `currency_utils.dart` | Price formatting helpers. | `formatPrice` (£35,000), `formatPriceCompact` (£35k). Uses GBP by default. |

---

### Models (`lib/models/`)

Shared data classes used across the entire app. These define the shape of all data.

| File | Purpose | Key Features |
|------|---------|--------------|
| `task.dart` | **The core entity.** Everything is a Task. | Fields: `taskId`, `taskName`, `taskType` (project or task), `parentTaskId` (links to parent project), `startTime`, `endTime`, `description`, `status`, `actionSpace` (list of available actions), `guidePrice` (AI-suggested price), `quotes`, `participants`, `metadata` (flexible JSON for future fields). Helper getters: `isProject`, `hasParent`, `acceptedQuote`, `pendingQuoteCount`, `durationDays`. Includes `fromJson`, `toJson`, and `copyWith`. |
| `quote.dart` | A quote from a contractor. | Fields: `contractorId`, `contractorName`, `amount`, `description`, `submittedAt`, `status` (pending/accepted/rejected). |
| `participant.dart` | A person involved in a task. | Fields: `userId`, `name`, `role`, `email`, `avatarUrl`, `phone`. |
| `message.dart` | Chat message and conversation models. | `Message`: id, senderId, type (text/image/invite/file), content, sentAt, isRead. `Conversation`: id, title, participantIds, lastMessage, unreadCount, linked taskId. |
| `alert.dart` | Notification/alert model. | Fields: id, title, body, taskId, createdAt, isRead, type. `AlertType` enum: quoteReceived, taskUpdated, taskCompleted, messageReceived, paymentDue, reminder. |
| `calendar_event.dart` | Calendar entry model. | Fields: id, title, taskId, date, startTime, endTime, description, type. `CalendarEventType` enum: taskStart, taskEnd, inspection, delivery, meeting, milestone. |

#### Enums (`lib/models/enums/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `task_type.dart` | `project` or `task`. | `label` getter for display text, `fromString` parser. |
| `task_status.dart` | Task lifecycle states. | Values: `draft`, `pending`, `inProgress`, `completed`, `cancelled`. Each has a `label`, `color` (for UI), and `icon`. |
| `quote_status.dart` | Quote states. | Values: `pending`, `accepted`, `rejected`. Each has a `label` and `color`. |
| `participant_role.dart` | Roles people can have. | Values: homeowner, contractor, designer, electrician, plumber, gasEngineer, labourer, inspector, landscapeDesigner, other. Each has a `label` and `icon`. |
| `message_type.dart` | Chat message types. | Values: `text`, `image`, `invite`, `file`. |

---

### Data Layer (`lib/data/`)

The repository pattern — abstracts where data comes from. Currently mock, real API later.

#### Repositories (`lib/data/repositories/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `task_repository.dart` | **Abstract interface** that defines all data operations. | Methods: `getAllTasks`, `getProjects`, `getTasksByProject(projectId)`, `getStandaloneTasks`, `getTaskById(taskId)`, `createTask`, `updateTask`, `deleteTask`, `searchTasks(query)`. |

#### Mock (`lib/data/mock/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `mock_task_repository.dart` | Mock implementation reading from JSON. | Loads `assets/data/mock_tasks.json` via `rootBundle`, parses into `Task` objects, caches in memory. Implements all repository methods with in-memory filtering. **Used now during frontend development.** |

#### Remote (`lib/data/remote/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `api_task_repository.dart` | Placeholder for real API implementation. | All methods throw `UnimplementedError` with TODO comments showing the expected API endpoints (e.g. `GET /api/tasks`, `POST /api/tasks`). **Implement when backend is ready.** |

---

### Providers (`lib/providers/`)

Riverpod state management — reactive data providers for the UI.

| File | Purpose | Key Features |
|------|---------|--------------|
| `task_provider.dart` | All task-related data providers. | `allTasksProvider` (all tasks), `projectsProvider` (projects only), `projectTasksProvider(projectId)` (subtasks), `standaloneTasksProvider`, `taskByIdProvider(taskId)`, `searchQueryProvider` + `searchResultsProvider` for search. |
| `selection_provider.dart` | Tracks card selection state on the home screen. | `selectedProjectIdProvider` (which project card is selected, nullable), `selectedTaskIdProvider` (which task card is selected, nullable), `homeTabProvider` (which tab is active: 0=Projects, 1=Tasks). |

---

### Features (`lib/features/`)

UI layer — one folder per bottom navigation tab, plus the actions system.

#### Shell (`lib/features/shell/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `app_shell.dart` | The navigation shell wrapping all tab screens. | `Scaffold` with `BottomNavigationBar` containing 5 tabs: Home, Networks, Calendar, Messages, Alerts. Uses `GoRouter` location to determine the active tab. Tab switching via `context.go()`. |

#### Home (`lib/features/home/`)

The main dashboard screen. Composed of modular sections.

| File | Purpose | Key Features |
|------|---------|--------------|
| `home_screen.dart` | Home tab root screen. | Greeting header ("Good morning/afternoon/evening!") with profile avatar. Composes: `SearchSection` → `ProjectTaskSection`. Uses `CustomScrollView` with `SliverAppBar`. |
| `sections/search_section.dart` | Search bar at the top of home. | Wraps the shared `AppSearchBar` widget. Placeholder for connecting to search provider. |
| `sections/project_task_section.dart` | **Main section** — tab toggle + carousel + contextual actions. | Animated Projects/Tasks tab toggle. Renders `_ProjectTab` or `_TaskTab` based on selection. Each tab composes `CardCarouselSection` + `ContextualActionSection`. Wires up selection providers and "See all" navigation via `ActionRouter`. |
| `sections/card_carousel_section.dart` | Horizontal single-card carousel with selection. | `PageView` with `viewportFraction: 0.85` showing one card at a time. Tap unselected card → confirmation dialog → selects. Tap selected card → deselection dialog → deselects. Swiping only browses (no auto-select). **Auto-snaps back** to selected card after 2 seconds of idle or when returning from another screen. Page indicator dots + "See all" link. |
| `sections/contextual_action_section.dart` | Action tiles that change based on selected card. | Reads from `ActionRegistry` for system actions. Has built-in configs for 5 project actions (Detail, Quote, Schedule, Photo, Invoice). Routes taps through `ActionRouter`. Shows selected card name in header. "Reorder" button placeholder. Fallback icons/colours for unknown actions. |
| `see_all_screen.dart` | Full-screen list for browsing all projects or tasks. | Searchable list. Tap a card → selection confirmation dialog → selects and pops back to home. Currently selected card shown with blue border, checkmark, and "Selected" badge. Works for both projects and tasks via `isProjects` flag. |

#### Actions (`lib/features/actions/`)

The action system — registry, router, and all action screens.

| File | Purpose | Key Features |
|------|---------|--------------|
| `action_registry.dart` | **Single source of truth** for all system actions. | 20 registered actions, each with: `key`, `label`, `description`, `icon`, `color`, `displayMode` (fullScreen/bottomSheet/webView), `screenType` (custom/form/confirmation/textInput/phone/web), `priority` (for AI ordering), `requiresData` (e.g. only show if task has quotes), `applicableTo` (filter by task type), `formFields` (for generic form screens), `confirmMessage`. Has `get()`, `isRegistered()`, `getByPriority()`, `taskMeetsRequirements()` methods. `fallback()` generates config for unknown actions so the app never crashes. |
| `action_router.dart` | Routes action tile taps to the correct destination. | Handles three flows: `open()` for system actions (reads registry, opens full screen/bottom sheet/web view), `openProjectAction()` for project-specific actions (Detail/Quote/Schedule/Photo/Invoice), `openCustomAction()` for user-created actions (web/phone/note). Includes generic bottom sheets: `_ConfirmationSheet` (yes/no actions like mark complete), `_TextInputSheet` (add note), `_FormSheet` (configurable fields like schedule inspection), `_PhoneSheet` (pick a participant to call), `_PlaceholderSheet` (coming soon fallback). |

##### Action Screens (`lib/features/actions/screens/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `project_task_list_screen.dart` | **Reusable** task list for project actions. | One screen, four modes via `TaskListMode` enum: detail, quote, schedule, invoice. Shows project's subtasks with mode-specific secondary info (descriptions for detail, quote counts for quote, duration for schedule, pricing for invoice). Tap a task → navigates to the mode-specific destination screen. Searchable. Used by all project actions except Photo. |
| `task_quote_screen.dart` | Quote management for a single task. | Task header with status. AI guide price card. Quote list with contractor avatars, amounts, descriptions, time-ago timestamps. Comparison to guide price (% above/below). Quote status badges (pending/accepted/rejected). Accept/reject buttons on pending quotes. "Request" button for new quotes. Empty state when no quotes exist. |
| `task_schedule_screen.dart` | Schedule management for a single task. | Start/end date cards with edit buttons. Duration indicator between dates. Progress card with percentage, progress bar, and remaining days. Overdue detection (red). Assigned participants chip list. "Reschedule" and "Add to Calendar" action buttons. |
| `task_invoice_screen.dart` | Invoice management for a single task. | Adapts to invoice state: no invoice (create button), draft (edit/send), issued (mark paid/send reminder), paid (download receipt). Invoice status card with state-specific icon, colour, and message. Cost breakdown showing guide price and accepted quote. Reads invoice state from `task.metadata['invoice']`. |
| `project_photo_screen.dart` | Photo gallery for a project. | Two sections: project-level photos (before/after) and task-level photos (grouped by subtask). Upload bottom sheet with three options: camera, gallery, files. Each subtask has its own "Add" button. FAB for quick photo upload. Empty states for all sections. |
| `web_view_screen.dart` | Generic in-app browser for web actions. | Placeholder screen showing URL and "Open in Browser" button. Ready to upgrade to real `WebView` with `webview_flutter` package. Used for actions like "Shop Materials" (Screwfix), "Select Colour" (Dulux), "Planning Advice" (Planning Portal). |

#### Network (`lib/features/network/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `network_screen.dart` | Network tab root screen. | App bar with "+" add person button. Search bar for filtering people. Composes `PeopleListSection`. |
| `sections/people_list_section.dart` | List of people in the user's network. | Cards showing name, role (with role-specific icon), chat and call action buttons. Mock data with 5 people (contractor, designer, electrician, landscape designer, gas engineer). |

#### Calendar (`lib/features/calendar/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `calendar_screen.dart` | Calendar tab root screen. | Composes `CalendarViewSection` + `TaskScheduleSection`. "Jump to today" button. |
| `sections/calendar_view_section.dart` | Interactive month calendar widget. | Month navigation (left/right arrows). Weekday headers. Day grid with tap-to-select. Highlights today (light blue) and selected date (solid blue). Built from scratch without external calendar packages. |
| `sections/task_schedule_section.dart` | Task list below the calendar. | Shows upcoming tasks sorted by start date. Each task has a coloured status bar, name, date range, and status badge. Connected to `allTasksProvider`. |

#### Chat (`lib/features/chat/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `chat_screen.dart` | Chat tab — WhatsApp-style conversation list. | Search bar for conversations. Mock conversation list with avatars (initial letter), last message preview, timestamp, and unread count badges. "New conversation" button. |

#### Alerts (`lib/features/alerts/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `alerts_screen.dart` | Alerts tab — notification feed. | "Mark all read" button. Alert cards with type-specific icons and colours (quote=amber, task update=blue, completed=green, message=primary, payment=red, reminder=purple). Relative timestamps ("3h ago"). Unread alerts have tinted background. Mock data with 6 alerts. |

#### Detail Screens (`lib/features/detail_screens/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `task_detail_screen.dart` | Full task detail view. | Header with task name + status badge. Description, timeline, duration, AI guide price, accepted quote. Quotes section listing all quotes with contractor name, amount, and description. Participants section with role icons. Action chips from `actionSpace`. Edit button. Used from both `/task/:taskId` route and the project Detail action's task list. |

---

### Shared Widgets (`lib/shared/`)

Reusable UI components used across multiple features.

#### Cards (`lib/shared/widgets/cards/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `project_card.dart` | Card for displaying a project (meta task). | Shows initial letter, status badge, description, date chip, guide price. Blue border highlight for in-progress projects. Accepts `onTap` callback. Used in carousel and can be reused anywhere. |
| `task_card.dart` | Card for displaying a regular task. | Shows task name, description, status badge, date range, guide price, participant count, pending quote indicator. |

#### Badges (`lib/shared/widgets/badges/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `status_badge.dart` | Coloured status chip. | Rounded pill with icon + label. Colour and icon derived from `TaskStatus` enum. Used across task cards, detail screens, calendar, and "see all" list. |

#### Inputs (`lib/shared/widgets/inputs/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `app_search_bar.dart` | Reusable search bar. | Configurable hint text, `onChanged` callback, optional `onTap` and `readOnly` for non-interactive use. Search icon prefix, filter icon suffix. |

#### Layout (`lib/shared/widgets/layout/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `section_header.dart` | Section title with optional action link. | "Projects" with "See all →" pattern. Accepts `title`, optional `actionText` + `onAction`, or a custom `trailing` widget. |

#### Feedback (`lib/shared/widgets/feedback/`)

| File | Purpose | Key Features |
|------|---------|--------------|
| `feedback_widgets.dart` | Loading, empty, and error state widgets. | `LoadingIndicator` (centered spinner), `EmptyState` (icon + title + subtitle + optional action button), `ErrorView` (error icon + message + retry button). |

---

### Assets

| File | Purpose |
|------|---------|
| `assets/data/mock_tasks.json` | 13 dummy tasks: 3 projects (Kitchen Renovation, Bathroom Refurbishment, Garden Landscaping) with project-specific actions (Detail, Quote, Schedule, Photo, Invoice), 8 project subtasks with task-specific actions, 2 standalone tasks (Emergency Boiler Repair, Living Room Painting). Covers all statuses, multiple quotes, various participant roles, and flexible metadata. |

---

## Data Model

Everything is a **Task**. A project is a task with `taskType: project`.

```
Task
├── taskId          (String)
├── taskName        (String)
├── taskType        (project | task)
├── parentTaskId    (String? — links to parent project)
├── startTime       (DateTime)
├── endTime         (DateTime)
├── description     (String)
├── status          (draft | pending | in_progress | completed | cancelled)
├── actionSpace     (List<String> — available actions for this task)
├── guidePrice      (double? — AI-suggested price)
├── quotes          (List<Quote>)
├── participants    (List<Participant>)
└── metadata        (Map — flexible JSON for future fields)
```

Hierarchy example:
```
Kitchen Renovation (project, parentTaskId: null)
├── Cabinet Demolition (task, parentTaskId: "proj-001")
├── Electrical Rewiring (task, parentTaskId: "proj-001")
└── Plumbing Rough-In (task, parentTaskId: "proj-001")

Emergency Boiler Repair (task, parentTaskId: null — standalone)
```

---

## Action System

### How It Works

```
User selects a card on home screen
  → actionSpace loaded (e.g. ["project_detail", "project_quote", ...])
  → Each action key resolved via ActionRegistry or project action config
  → Tiles rendered with icon, colour, label
  → User taps a tile
  → ActionRouter decides: full screen / bottom sheet / web view
  → Correct screen or sheet opens
```

### Action Types

| Type | Display Mode | Examples | Needs Compilation? |
|------|-------------|----------|-------------------|
| System (registered) | Full screen | Review Quotes, Assign Contractor | Yes — custom Flutter UI |
| System (registered) | Bottom sheet | Add Note, Mark Complete, Schedule | Yes — but uses generic reusable sheets |
| System (registered) | Web view | Shop Materials, Select Colour | No — just a URL |
| Project-specific | Full screen | Detail, Quote, Schedule, Photo, Invoice | Yes — built once, reusable |
| Custom (user-created) | Web/phone/note | User's bookmarks, links, contacts | No — never needs compilation |

### Adding a New Action

**System action with custom UI:**
1. Add entry to `action_registry.dart`
2. Build the screen/sheet in `lib/features/actions/screens/`
3. Add route in `action_router.dart`
4. Requires app update

**System action with generic UI (form, confirmation):**
1. Add entry to `action_registry.dart` with `screenType: form/confirmation`
2. Configure `formFields` or `confirmMessage`
3. No new screen needed — reuses generic sheets
4. Requires app update (but minimal code change)

**Web action:**
1. Build the web page on your server
2. Add entry to `action_registry.dart` with `displayMode: webView` and `url`
3. No custom screen needed
4. Web page can be updated without app release

**Custom user action:**
1. User taps "+" on action area
2. Enters label, picks icon, enters URL/phone
3. No code changes, no app update, no registration

---

## Switching to Real Backend

1. Set `useMockData` to `false` in `lib/core/config/app_config.dart`
2. Implement the methods in `lib/data/remote/api_task_repository.dart`
3. The UI stays exactly the same — no other changes needed

---

## Development Phases

### Phase 1 — Scaffold & Mock Data ✅
- Project structure, models, mock repository, navigation shell, home screen

### Phase 2 — Core Home UI ✅
- Card carousel with selection/deselection confirmation dialogs
- Contextual action tiles from task.actionSpace
- "See all" full-screen list with search and selection
- Auto-snap-back to selected card

### Phase 3 — Action System ✅
- Action Registry with 20 registered system actions
- Action Router with full screen / bottom sheet / web view routing
- Project actions: Detail, Quote, Schedule, Photo, Invoice
- Reusable project task list screen with 4 modes
- Task quote screen with comparison and accept/reject
- Task schedule screen with progress tracking
- Task invoice screen with lifecycle states
- Project photo screen with upload options
- Generic web view screen
- Generic bottom sheets: confirmation, text input, form, phone, placeholder

### Phase 4 — Other Tabs ✅
- Network, Calendar, Chat, Alerts screens with mock data

### Phase 5 — Polish & UX
- Loading skeletons, animations, pull-to-refresh, error handling
- Custom user action creation ("+") button and bottom sheet
- Action reordering

### Phase 6 — Connect Real Backend
- Implement API repositories, authentication, push notifications
- Move action registry to backend config API
- Real WebView integration (`webview_flutter`)

### Phase 7 — AI Integration
- AI agent reads ActionRegistry to recommend actions
- AI-powered action ordering based on task state and priority
- AI project manager suggestions ("You have 3 quotes to review")