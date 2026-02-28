# BuilderVet

A renovation platform for managing tasks, projects, contractors, and quotes.

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.2.0)
- Xcode (for iOS) or Android Studio (for Android)

### Setup

```bash
# Clone the repo
git clone <your-repo-url>
cd buildervet

# Install dependencies
flutter pub get

# Run on connected device or simulator
flutter run
```

### Project Structure

```
lib/
├── core/          # Theme, routing, config, utilities
├── models/        # Data models (Task, Quote, Participant, etc.)
├── data/          # Repository pattern (mock now, API later)
├── providers/     # Riverpod state management
├── features/      # UI screens (one folder per tab)
│   ├── shell/     # Bottom navigation shell
│   ├── home/      # Home tab (search, projects, tasks, actions)
│   ├── network/   # Network tab (people)
│   ├── calendar/  # Calendar tab
│   ├── chat/      # Chat tab
│   ├── alerts/    # Alerts tab
│   └── detail_screens/
└── shared/        # Reusable widgets
```

### Switching to Real Backend

1. Set `useMockData` to `false` in `lib/core/config/app_config.dart`
2. Implement the API repositories in `lib/data/remote/`
3. That's it — the UI stays the same

## Architecture

- **Feature-first** folder structure
- **Section-based** screens (modular, add/remove sections easily)
- **Repository pattern** for clean mock → API swap
- **Riverpod** for state management
