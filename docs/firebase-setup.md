# Firebase Setup — BizBrain AI

This document describes how the BizBrain AI Flutter client is configured for a
Firebase project, how environments are separated, and which platform-specific
steps remain outstanding.

## Configuration architecture

All Firebase configuration flows through the existing resolver chain. Nothing
is hardcoded in source.

| Layer | File | Responsibility |
| --- | --- | --- |
| Environment | `lib/core/config/app_config.dart` | Reads `APP_ENV` (`development` / `staging` / `production`, default `development`) and `APP_BUILD`. |
| Option resolver | `lib/core/config/firebase_options.dart` | Reads the `FIREBASE_*` `--dart-define` values and returns `FirebaseOptions?` — `null` when any required key is missing or empty. |
| Bootstrap | `lib/app/bootstrap/app_bootstrap.dart` | Calls the resolver; starts the SDK with `Firebase.initializeApp(options: …)`; returns one of three honest states: `configured`, `notConfigured`, `failed`. Never throws. |
| Provider | `lib/core/config/app_providers.dart` | `firebaseInitializationProvider` — the safest default is `notConfigured`, overridden once in `main()` with the bootstrap result. |
| Auth selection | `lib/features/authentication/presentation/providers/auth_providers.dart` | `configured` → real `FirebaseAuthRepository`; anything else → `UnconfiguredAuthRepository` that refuses every operation. |

Required defines (a build missing any of them stays **unconfigured** and never
touches the Firebase SDK):

```
FIREBASE_API_KEY
FIREBASE_AUTH_DOMAIN
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_APP_ID
```

Optional defines: `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MEASUREMENT_ID`.

`FIREBASE_*` values are **Firebase client configuration** — a public
identifier of a project that ships inside every compiled client. It is
protected by Security Rules and App Check, never by secrecy. Service-account
keys, admin SDK credentials and other privileged tokens must never appear in
these files (`.gitignore` blocks the common credential file patterns).

## Local development run command

The development configuration lives in a **local, Git-ignored** JSON file that
is fed to the compiler with `--dart-define-from-file`:

```bash
flutter run -d chrome --dart-define-from-file=config/firebase.development.json
```

On a fresh clone (or when the local file is absent), create it from the
tracked template first:

```bash
# macOS / Linux
cp config/firebase.development.example.json config/firebase.development.json
# Windows (cmd)
copy config\firebase.development.example.json config\firebase.development.json
```

Then replace the `REPLACE_WITH_*` placeholders with the values of the target
Firebase project's **Web** app, or use the file already provided locally.

Related commands:

```bash
# configured test run (config parsing / initialization tests)
flutter test test/core/config --dart-define-from-file=config/firebase.development.json

# configured web build
flutter build web --dart-define-from-file=config/firebase.development.json

# unconfigured build (no defines) — must remain the safe default
flutter build web
```

Without any `--dart-define-*` argument the build is **unconfigured by
design**: the app starts, the startup screen reports
`Firebase not configured` with the missing keys listed, and authentication /
data features stay disabled. This is the required behaviour for fresh clones
and CI.

## Environment separation

| Environment | Config file | Firebase project |
| --- | --- | --- |
| development | `config/firebase.development.json` (local, Git-ignored) | `bizbrain-e3a61` — the supplied development project |
| staging | `config/firebase.staging.example.json` (template only) | **Not provisioned.** Requires its own Firebase project. |
| production | `config/firebase.production.example.json` (template only) | **Not provisioned.** Requires its own Firebase project. |

* The supplied configuration is treated as **development only**. It is not
  assumed to be production.
* No additional Firebase projects were created, and none are created by this
  repository — staging/production files stay as `REPLACE_WITH_*` templates
  until such projects exist and are explicitly approved.
* The environment is carried by `APP_ENV` inside each file and surfaced on the
  startup screen (`DEVELOPMENT · build local`, …), so a build can never claim
  an environment different from the one it was compiled with.
* Never point a production `APP_ENV` at the development project: copy the
  staging/production template instead and fill in that environment's own
  project values.

## Platform safety (Web configuration only)

The supplied configuration is for the **Web** application of the project:

* `FIREBASE_APP_ID` is a `…:web:…` app id. It is valid for the `web/` build
  only.
* **Do not** reuse the Web app id as an Android or iOS app id — app ids are
  per-platform and per-app.
* **Do not** invent Android/iOS Firebase options. This repository deliberately
  contains no `android/app/google-services.json` and no
  `ios/Runner/GoogleService-Info.plist` (both are Git-ignored so they can
  never be committed by accident).

Mobile platforms require their own, platform-specific setup — not part of
this step and **outstanding**:

1. Register an Android app (package name) and an iOS app (bundle id) in the
   Firebase project — each gets its **own** app id.
2. Download `google-services.json` / `GoogleService-Info.plist` from the
   Firebase console into `android/app/` / `ios/Runner/`.
3. Apply the corresponding FlutterFire / Google Services Gradle and plist
   wiring.

The current code base only *reads* `FIREBASE_*` dart-defines, so the same
resolver works unchanged once platform files exist; until then mobile builds
simply remain unconfigured.

## How initialization behaves

* **Parsing** — `AppFirebaseOptions.resolve()` builds `FirebaseOptions` only
  when every required define is non-empty; otherwise it returns `null`.
* **Start** — `AppBootstrap.initialize()` passes the resolved options to
  `Firebase.initializeApp(options: …)`; the projectId of the started options
  is logged.
* **Missing configuration** — the bootstrap reports
  `FirebaseInitStatus.notConfigured` with the exact missing keys; the SDK is
  never started; the default provider value is also `notConfigured` so a
  missing bootstrap override cannot fake readiness.
* **Initialization errors** — the bootstrap reports
  `FirebaseInitStatus.failed` with a truncated, single-line reason; the app
  still starts and shows the failure on the startup screen.
* **Project isolation** — there are no fallback/hardcoded project values:
  without the defines the SDK is never started, and with them the exact
  compiled values are used. The configuration tests assert that the started
  options match the supplied project (`bizbrain-e3a61`), that the Web app id
  and the messaging sender id belong to the same project number, and that a
  missing value yields `notConfigured` instead of a substitute project.

No Firestore writes, no Authentication changes, no rules deployment and no
console changes are performed by this step.

## Verification status

See the Step 1.5 report for the exact command results. In short:

* `dart format lib test`, `flutter analyze`, plain `flutter test` and plain
  `flutter build web` all pass (the plain build is intentionally
  unconfigured).
* The focused configuration tests are additionally executed with
  `--dart-define-from-file=config/firebase.development.json` and pass.
* A web build/`flutter run` succeeding is **not** evidence of live Firebase
  connectivity; only the startup screen showing `Firebase configured` after a
  configured run demonstrates the SDK accepted the options.
