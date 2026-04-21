# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**flutter_control_parental** is a Flutter plugin that wraps Apple's Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) for iOS 16+. It provides a Dart interface for authorization, app selection, shield configuration, schedule-based monitoring, and temporary access grants.

**Key architectural split**: the plugin owns the Flutter API, method channel bridge, and configuration persistence. The **host iOS app** owns Screen Time extension targets (ShieldConfiguration, ShieldAction, DeviceActivityMonitor), entitlements, signing, and shield-screen presentation. Sample extension code lives in `templates/ios/`.

**Version**: 0.1.5 | **SDK**: Flutter >=3.22.0, Dart ^3.0.0 | **Platform**: iOS only (Android removed)

## Build & Development Commands

```bash
flutter pub get                # Install dependencies
flutter analyze                # Lint (uses flutter_lints)
dart format lib/ test/         # Format code

# Example app (requires real device or simulator with Screen Time capabilities)
cd example && flutter run -v   # Debug build
cd example && flutter run --release
```

**Xcode**: Always open `example/ios/Runner.xcworkspace` (not `.xcodeproj`) for CocoaPods support.

No unit or integration tests exist currently (`test/` directory is empty).

## High-Level Architecture

### Dart Layer — Four Domain Classes

The API is split into four classes, each wrapping a distinct iOS framework concern. All share the same `MethodChannel('flutter_control_parental')`.

| Class | File | Responsibility |
|---|---|---|
| `FamilyControls` | `lib/src/family_controls.dart` | Authorization (check/request/revoke), app picker, notification permission |
| `ManagedSettings` | `lib/src/managed_settings.dart` | Start/stop blocking, blocking status, app group ID |
| `DeviceActivity` | `lib/src/device_activity.dart` | Schedule CRUD, start/stop monitoring |
| `ShieldExtension` | `lib/src/shield_extension.dart` | Shield UI config, shield icon, temporary access, event streams |

Models are in `lib/src/models/`: `ScreenTimeAuthorizationStatus`, `SelectedAppsSummary`, `ScreenTimeBlockScreenConfig`, `ScreenTimeSchedule`, `ActivityEvent`.

Public barrel export: `lib/flutter_control_parental.dart` — re-exports models and all four classes (with `hide` to avoid duplicate symbol exports).

### iOS Native Layer — Single Plugin File

`ios/Classes/FlutterControlParentalPlugin.swift` handles all method calls in one `switch` statement organized by `// MARK:` sections (FamilyControls, ManagedSettings, DeviceActivity, ShieldExtension, Diagnostics, Legacy).

**Event channels** (two-way communication from extensions to Flutter):
- `flutter_control_parental/shield_action` — emits `ShieldAction` when user taps shield buttons
- `flutter_control_parental/activity_event` — emits `ActivityEvent` from DeviceActivityMonitor extension

**Inter-process communication** (extension → main app): Darwin Notifications (`CFNotificationCenter`) + shared `UserDefaults` (App Group). The plugin observes notifications, reads event data from shared defaults, and forwards to Flutter via EventChannel sinks. A pending-action mechanism handles the case where the app is backgrounded when the shield action occurs.

### Storage Keys (App Group shared defaults)

All persisted under `flutter_control_parental.*` prefix in both `UserDefaults.standard` and the App Group suite. Extensions read from the App Group to render shields and fire events. Key keys:
- `.sharedContainerId`, `.blockScreenConfig`, `.blockedSelection`, `.blockingEnabled`, `.activitySchedule`, `.shieldIcon`, `.lastActivityEvent`

### Extension Templates

`templates/ios/` contains sample implementations for three extension types:
- `ShieldConfigurationExtension` — renders the custom block screen
- `ShieldActionExtension` — handles shield button taps, writes to App Group + posts Darwin Notification
- `DeviceActivityMonitorExtension` — fires on schedule interval start/end/threshold

Host app must: add these as Xcode targets, share the same App Group, and enable FamilyControls entitlement.

## Adding a New Method to the Plugin

1. Add method to the appropriate Dart class in `lib/src/` (or create a new class if it's a new domain)
2. Add model classes to `lib/src/models/` if serialization is needed; update barrel export in `lib/flutter_control_parental.dart`
3. Add case to the `switch` in `FlutterControlParentalPlugin.swift:handle(_:result:)`
4. If it needs extension↔app communication: use Darwin Notifications + shared defaults pattern (see `handleShieldActionNotification()` for reference)

## Important Design Decisions

1. **iOS-only**: Android overlay service was removed. `pubspec.yaml` only registers the iOS `pluginClass`.

2. **Host owns extensions**: Plugin does NOT create extension targets. This allows host apps to customize shield content, handle actions differently, and manage their own entitlements/signing.

3. **Configuration persistence**: All config stored in both standard UserDefaults and App Group shared defaults. The `persist()` helper in Swift writes to both, with `sanitize()` stripping NSNull values.

4. **Authorization target**: `requestAuthorization(for: .child)` — the plugin targets the child member authorization flow specifically.

5. **Temporary access**: `grantTemporaryAccess` clears the ManagedSettingsStore, then uses `DeviceActivitySchedule` (iOS 16+) to re-apply blocking after the duration expires. Falls back to in-memory `DispatchQueue` timer if scheduling fails.

6. **Shield action delivery**: Uses a multi-layer approach — Darwin Notification for immediate delivery, `pendingShieldAction` + `applicationDidBecomeActive` for deferred delivery when app is backgrounded, and local notifications to bring the app to foreground.
