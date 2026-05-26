# TipidTrack Copilot Instructions

## Build, test, and lint commands

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter test --plain-name "Counter increments smoke test" test/widget_test.dart
flutter build apk
flutter build web
```

Current baseline:

- `flutter analyze` is not clean. It currently reports a syntax issue near the end of `lib/screens/profile_screen.dart`, an unused local function in `lib/screens/expenses_screen.dart`, and a stale widget test in `test/widget_test.dart`.
- `test/widget_test.dart` still instantiates `MyApp`, but the app entry widget is `TipidTrackApp` in `lib/main.dart`.

## High-level architecture

- This is a Flutter app with a single `MaterialApp` entry point in `lib/main.dart`. The app theme is defined there with Material 3 and Google Fonts, and the initial route is `SplashScreen`.
- The user flow is `SplashScreen` → `LandingScreen` → `AuthScreen` for signup/login, then `DashboardScreen` after a successful login.
- Authentication and lightweight session state live in the in-memory singleton `AppSession` (`lib/services/session.dart`). It stores the bearer token, user name, email, and a one-shot `showGuideAfterLogin` flag. There is no wider state-management framework or persisted auth session.
- API calls are made directly inside screen widgets with `package:http`; there is no separate repository/service layer beyond `AppSession`. Screens that talk to the backend each define their own `_apiBaseUrl = 'https://tipidtrack.dcism.org'` and call endpoints such as:
  - `/api/signup`, `/api/login`, `/api/reset-password`
  - `/api/balance`, `/api/transactions`, `/api/cards`
  - `/api/profile`, `/api/profile/name`, `/api/profile/password`
- `DashboardScreen`, `ExpensesScreen`, `CardsScreen`, and `ProfileScreen` are the main authenticated surfaces. `DashboardScreen` loads balance and transactions; `ExpensesScreen` derives totals and category summaries from `/api/transactions`; `CardsScreen` loads cards; `ProfileScreen` updates profile data and account state.
- `SharedPreferences` is only used for the dashboard onboarding guide (`hasSeenGuide`). The guide is triggered by `AppSession.showGuideAfterLogin` and persisted with the `hasSeenGuide` flag so it only shows once unless reset from `ProfileScreen`.
- The spending insight screens (`spending_allocation_screen.dart`, `spending_category_screen.dart`, `category_detail_screen.dart`) are currently UI-first screens that use `fl_chart` and hard-coded demo data rather than live backend data.

## Key conventions

- Keep most UI code screen-local. Each screen file defines its own private helper widgets and private data mappers with underscore-prefixed classes such as `_TransactionItem`, `_CardItem`, `_CategoryTile`, and `_SectionCard`.
- Navigation is done imperatively with inline `MaterialPageRoute` calls (`Navigator.of(context).push`, `pushReplacement`, or `pushAndRemoveUntil`), not named routes or a router package.
- Authenticated requests read the bearer token from `AppSession.instance.token` and send it in the `Authorization: Bearer ...` header. New authenticated features should follow that pattern unless the session model is being deliberately refactored.
- JSON parsing is defensive and screen-local: responses are decoded in the screen, mapped into small private model classes, and missing fields usually fall back to safe defaults like `'General'`, `'Card'`, or `0.0`.
- Success and error feedback is typically shown with a local `_showMessage()` helper that wraps `ScaffoldMessenger.of(context).showSnackBar(...)`.
- Styling is mostly repeated per screen with local constants like `brandColor`, `surfaceColor`, and `mutedText`, plus rounded white cards and soft shadows. Prefer matching that existing pattern rather than introducing a new design system in isolated changes.
