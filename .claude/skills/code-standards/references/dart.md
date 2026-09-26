# Dart / Flutter Standards

Verified: 2026-09-26

| Item | Version | Source |
| --- | --- | --- |
| Flutter | 3.47.5 stable | https://docs.flutter.dev/release/archive |
| Dart | 3.13.4 (bundled with Flutter 3.47) | https://dart.dev/get-dart |
| Effective Dart | current | https://dart.dev/effective-dart |
| `dart format` | bundled (tall style, language-version aware) | https://dart.dev/tools/dart-format |
| flutter_lints / lints | 6.0.0 / 6.1.0 | https://pub.dev/packages/flutter_lints |
| flutter_secure_storage | 11.2.0 | https://pub.dev/packages/flutter_secure_storage |
| mocktail | 1.0.5 | https://pub.dev/packages/mocktail |
| App architecture guide | current | https://docs.flutter.dev/app-architecture |

## Tooling

- Pin the Flutter SDK per project with FVM (`.fvmrc`, `fvm use 3.47.5`) or document the
  version in `pubspec.yaml` `environment`. Do not rely on a global SDK version.

```yaml
environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"
```

- Dependencies are project-scoped by design (`pubspec.yaml` + `pubspec.lock`). Add them with
  `flutter pub add <pkg>` / `dart pub add <pkg>`; dev tools with `--dev`. Never
  `dart pub global activate` a tool the project depends on; add it as a dev dependency and run
  it with `dart run <tool>`.
- Commit `pubspec.lock` for apps. Packages (libraries) may omit it.
- **Formatter**: `dart format .` with default settings. Optional width in `analysis_options.yaml`
  (`formatter: page_width: 100`); do not fight the formatter with manual layout.
- **Analyzer**: `analysis_options.yaml` at the package root. Flutter apps include
  `flutter_lints`; pure Dart packages include `package:lints/recommended.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    unawaited_futures: error
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_print
    - prefer_final_locals
    - unawaited_futures
```

  `very_good_analysis` is an acceptable stricter alternative if the project opts in.
- Code generation (`build_runner`, `freezed`, `json_serializable`) only when it removes real
  boilerplate; generated files are not edited by hand.
- Commands: `dart format .`, `flutter analyze` (or `dart analyze` for pure Dart),
  `flutter test`, `dart fix --apply` for automated migrations.

## Project Layout

Follow the Flutter app architecture guide (UI layer + data layer, MVVM):

```text
pubspec.yaml
pubspec.lock
analysis_options.yaml
lib/
  main.dart                 # thin: config, dependency wiring, runApp
  ui/
    core/                   # shared widgets, theme
    <feature>/
      <feature>_screen.dart
      <feature>_view_model.dart
  data/
    repositories/           # source of truth, exposes domain models
    services/               # API clients, platform plugins
  domain/models/            # immutable models
  config/                   # environment, routing
test/                       # mirrors lib/
integration_test/
assets/
android/  ios/              # platform projects (committed for Flutter)
```

- Pure Dart packages: public API in `lib/<package>.dart`, implementation in `lib/src/`.
- One public widget per file for non-trivial widgets.
- State management: pick one per project (`provider`/`ChangeNotifier` per the architecture
  guide, or Riverpod / Bloc if already chosen) and use it consistently.

## Naming

- Effective Dart: `UpperCamelCase` types and extensions; `lowerCamelCase` members, variables,
  constants and enum values; `lowercase_with_underscores` files, directories and packages.
- Functions and methods are Action-Object: `fetchUser()`, `validateEmail()`, `parseToken()`.
- Acronyms longer than two letters are capitalized like words: `HttpClient`, `userId`.
- Private members start with `_`; prefer library privacy over extra classes.
- Widgets are nouns (`UserAvatar`); callbacks are `onVerb` (`onSubmit`).

## Security Specifics

- **The app binary is public.** Values passed with `--dart-define` / `--dart-define-from-file`
  are compiled into the app and extractable. Never embed API secrets or private keys; keep them
  on a backend. Keep `--dart-define-from-file` inputs out of git.
- **Token storage**: `flutter_secure_storage` (Keychain / Keystore). Never
  `shared_preferences`, Hive without encryption, or plain files for secrets.
- **Release builds**: `flutter build <target> --obfuscate --split-debug-info=<dir>`; keep the
  symbol files private for crash symbolication.
- **Network**: HTTPS only (`Uri.https`). Keep Android cleartext traffic disabled and iOS ATS
  enabled. Set timeouts on HTTP clients. Consider certificate pinning for high-risk APIs.
- **Input**: validate form input and every deep link / route parameter before use; parse JSON
  into typed models (`fromJson` with explicit checks), never trust `dynamic`.
- **SQL**: `sqflite`/`drift` with bound arguments (`whereArgs`, variables); never interpolate
  input into SQL strings.
- **Files**: resolve paths under the app's documents/cache directory and reject `..`
  segments from external input.
- **WebView**: avoid for untrusted content; restrict JavaScript channels and allowed origins.
- **Logs**: use a logger that is silenced in release; no tokens or personal data in logs.
  `avoid_print` enforces no stray `print`.
- **Platform permissions**: request only when needed, with purpose strings in the target
  user language (`Info.plist`, `AndroidManifest.xml`).

## Testing

- `flutter test`: unit tests for view models, repositories and services; widget tests for UI;
  `integration_test/` for flows on a device or emulator.
- Test files `*_test.dart` mirroring `lib/` paths.
- Mock with `mocktail`; fake repositories over deep mocks.
- Test names describe behavior in English: `test('rejects an expired token', ...)`.
- Golden tests only for stable, design-critical widgets.

## Checklist

- [ ] `dart format --set-exit-if-changed .` produces no changes.
- [ ] `flutter analyze` (or `dart analyze`) reports no issues with strict language options.
- [ ] `flutter test` passes.
- [ ] No secrets in code, `--dart-define` values, or assets; tokens in `flutter_secure_storage`.
- [ ] Release builds obfuscated; no cleartext HTTP; permissions minimal with purpose strings.
- [ ] Deep link and form input validated; JSON parsed into typed models.
- [ ] `pubspec.lock` committed for apps; new env/config values documented in `.env.example`.
