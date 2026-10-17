# Dart / Flutter Standards

Verified: 2026-10-12

| Item | Version | Source |
| --- | --- | --- |
| Flutter | 3.47.7 stable | https://docs.flutter.dev/release/archive |
| Dart | 3.13.5 (bundled with Flutter 3.47.7) | https://dart.dev/get-dart |
| Effective Dart | current | https://dart.dev/effective-dart |
| `dart format` | bundled (tall style, language-version aware) | https://dart.dev/tools/dart-format |
| flutter_lints / lints | 6.0.0 / 6.1.0 | https://pub.dev/packages/flutter_lints |
| flutter_secure_storage | 11.2.0 | https://pub.dev/packages/flutter_secure_storage |
| mocktail | 1.0.5 | https://pub.dev/packages/mocktail |
| App architecture guide | current | https://docs.flutter.dev/app-architecture |

## Tooling

- Pin the Flutter SDK per project with FVM (`.fvmrc`, `fvm use 3.47.7`) or document the
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

## Project Layout

Follow the Flutter app architecture guide (UI layer + data layer, MVVM):

```text
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
android/  ios/              # platform projects (committed for Flutter)
```

- One public widget per file for non-trivial widgets.
- State management: pick one per project (`provider`/`ChangeNotifier` per the architecture
  guide, or Riverpod / Bloc if already chosen) and use it consistently.

## Naming

No rules beyond the core rules.

## Security Specifics

- Values passed with `--dart-define` / `--dart-define-from-file` are compiled into the app and
  extractable; keep `--dart-define-from-file` inputs out of git and secrets on a backend.
- Tokens and credentials in `flutter_secure_storage`, not `shared_preferences` or unencrypted
  Hive.
- Release builds: `flutter build <target> --obfuscate --split-debug-info=<dir>`; keep the
  symbol files private.
- `Uri.https` only; Android cleartext traffic disabled, iOS ATS enabled; HTTP client timeouts;
  certificate pinning for high-risk APIs.
- SQL via `sqflite`/`drift` bound arguments (`whereArgs`, variables).
- File paths resolved under the app's documents/cache directory.
- Permission purpose strings (`Info.plist`, `AndroidManifest.xml`) are user-facing (target
  user language).

## Testing

- `flutter test` + `integration_test/`; mock with `mocktail`, prefer fake repositories over
  deep mocks.

## Checklist

- [ ] `flutter test` passes.
- [ ] Release builds use `--obfuscate --split-debug-info`.
