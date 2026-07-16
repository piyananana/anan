# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (web/desktop/mobile)
flutter run

# Run on a specific device
flutter run -d chrome
flutter run -d windows

# Build
flutter build web
flutter build windows

# Lint / static analysis
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Install dependencies
flutter pub get
```

## Architecture Overview

This is **ANAN System** — a multi-module ERP/accounting Flutter application (Thai-language UI). It targets web and desktop. There is no `go_router` usage despite it being listed as a dependency; navigation is done via `Navigator.push`/`pushAndRemoveUntil`.

### Module Structure (`lib/`)

The codebase is split into three business modules, each as a subdirectory with its own `models/`, `screens/`, `services/`, and `widgets/` folders:

| Module | Path | Domain |
|--------|------|--------|
| **SA** (System Admin) | `lib/sa/` | Auth, users, groups, menus, permissions, company, backup |
| **CD** (Common Data) | `lib/cd/` | Branch, business unit, currency, project, zipcode |
| **GL** (General Ledger) | `lib/gl/` | Chart of accounts, periods, GL entries, financial reports |

### State Management

`Provider` is used throughout. All services are registered as `Provider`/`ChangeNotifierProvider` in `main.dart`. `AuthService` is a `ChangeNotifier` singleton; all other services are plain singletons instantiated via factory constructors.

### Authentication Flow

1. `main.dart` checks `AuthService.isLoggedIn()` (validates JWT with backend via `/api/sa/auth/check_token`)
2. Routes to `LoginScreen` (no token) or `HomeScreen` (valid token)
3. On login, JWT + selected database name are stored in `SharedPreferences`
4. Every API call reads the token via `AuthService.getAuthHeader()`, which injects `Authorization: Bearer <token>`, `X-Database-Name`, `UserId`, and `UserName` headers

### API Communication

Base URLs are centralized in `lib/config/app_config.dart`:

```dart
static const String baseHost = 'http://localhost:8888'; // dev
// static const String baseHost = '';                   // production
```

- **Dev** (`flutter run -d chrome`): ตั้ง `baseHost = 'http://localhost:8888'` เพื่อให้ชี้ไปที่ backend โดยตรง
- **Production**: ตั้ง `baseHost = ''` เพื่อใช้ relative URL เพราะ Express backend เสิร์ฟ Flutter web build (`anan_backend/build/web/`) จาก origin เดียวกัน

ทุก service ใช้ `AppConfig.apiSa`, `AppConfig.apiGl`, `AppConfig.apiCd` — ห้ามใช้ URL hardcode ในไฟล์ service โดยตรง

### Dynamic Menu / Screen Registry

The `Menu` model (`lib/sa/models/menu.dart`) contains a static `_staticWidgetBuilders` map that maps string screen names (e.g. `'GlEntryScreen'`) to widget constructors. Menus are fetched from the backend; each menu item's `target_path` field must exactly match a key in this map. **When adding a new screen, you must register it in `Menu._staticWidgetBuilders`.**

### Home Screen Layout

`HomeScreen` uses `flutter_resizable_container` with a 3-panel layout:
1. Narrow toggle button (collapse/expand left panel)
2. Left panel: `MenuTreeView` (collapsible tree navigation)
3. Right panel: `TabBar` + `TabBarView` — each selected menu item opens as a closeable tab

### Bilingual Support (Thai / English)

The app supports Thai/English switching via `LanguageProvider` (`lib/sa/services/sa_language_provider.dart`).

**Rules — apply every time you touch a screen:**

1. **Read language in `build()`** and save to instance variable:
   ```dart
   bool _isEnglish = false; // field in State class

   @override
   Widget build(BuildContext context) {
     final isEnglish = context.watch<LanguageProvider>().isEnglish;
     _isEnglish = isEnglish; // lets async methods access it without context
     ...
   }
   ```

2. **Company name** — always use `company.displayName(isEnglish)`, never `.thaiName` directly:
   ```dart
   // Company model has: String displayName(bool isEnglish)
   final companyName = _company?.displayName(_isEnglish) ?? '(No company name)';
   ```

3. **Account name in lists/trees** — `Account` has both `accountNameThai` and `accountNameEng`:
   ```dart
   isEnglish && item.accountNameEng.isNotEmpty
       ? item.accountNameEng : item.accountNameThai
   ```

4. **Account type label** — use helper from `gl_account.dart`:
   ```dart
   import '../models/gl_account.dart';
   accountTypeLabel(type, isEnglish) // returns Thai or English label
   ```

5. **In async methods** (PDF, Excel): use `final isEnglish = _isEnglish;` at the top — never pass `context` into async.

6. **In dialog callbacks**: `final isEnglish = context.read<LanguageProvider>().isEnglish;`

7. **Excel report headers**: bilingualize company name (`displayName`), report title, column headers, and print-date label.

8. **PDF report headers**: same as Excel — company name, page label (`หน้า`/`Page`), printed-by (`พิมพ์โดย`/`Printed by`), print-date (`พิมพ์เมื่อ`/`Printed`).

9. **`AppL10n`** (`lib/sa/services/sa_app_l10n.dart`) provides standard labels (close, cancel, save, etc.) — use it instead of hardcoding.

---

### PDF / Printing

The `pdf` and `printing` packages are used in the GL module for generating financial reports (financial report, general ledger, trial balance).

### Fonts

Custom Thai fonts are registered in `pubspec.yaml`: `tahoma` (default app font), `cordia`, `THSarabun`, `upcd`. These are used extensively in PDF generation for Thai character support.
