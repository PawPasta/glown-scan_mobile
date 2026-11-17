# GlowScan Mobile — Android-First Instructions

## Current delivery focus

Android is the active product target. Prioritize Android behaviour, Android
permissions, Android release builds, and Flutter code used by Android.

Treat these paths as in scope by default:

- `lib/`
- `test/`
- `android/`
- shared project configuration required to build Android, including
  `pubspec.yaml`, `pubspec.lock`, and `.github/workflows/`.

## Non-Android platforms

The following platform folders are out of scope unless a task explicitly names
them or a change directly affects them:

- `ios/`
- `macos/`
- `web/`
- `windows/`
- `linux/`

Do not add, update, or run platform-specific tests/builds for those folders as
part of Android-focused work. Preserve their existing files and report any
cross-platform limitation instead of changing their implementation by default.

## Testing expectations

For Android-focused Flutter changes, add focused Dart unit/widget tests for the
changed behaviour. Run the Android-first quality gates in
`.codex/WORKFLOW.md`. A web release build is not required unless the user asks
for web support or the changed task is explicitly cross-platform.

## Delivery discipline

Keep changes small, avoid logging tokens or other sensitive data, and never
commit or push without the authorization and verification required by the
workflow.
