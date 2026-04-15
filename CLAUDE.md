# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**flutter_screentime** is a Flutter plugin that provides screen time style app blocking with platform-specific implementations:

- **iOS**: Leverages native FamilyControls framework (iOS 16+) with ManagedSettingsStore for app shielding. The plugin provides the Dart API and native bridge; host apps own Screen Time extension targets, entitlements, signing, and final shield-screen presentation.
- **Android**: Implements a foreground overlay service with usage stats monitoring to display a custom block screen when blocked apps come to foreground. Uses SYSTEM_ALERT_WINDOW and PACKAGE_USAGE_STATS permissions.

The plugin splits concerns: plugin owns Flutter API, native method channels, and Android overlay service; host iOS app owns extension targets and capabilities. This architecture allows flexible customization of blocked-screen content while maintaining a clean plugin boundary.

**Version**: 0.1.5 | **SDK**: Flutter >=3.22.0, Dart ^3.0.0

## High-Level Architecture

### Plugin Structure

```
lib/
├── flutter_screentime.dart           # Main public API export
└── src/flutter_screentime_api.dart   # Core Dart implementation
```

### Data Flow

1. **Dart Layer** (`flutter_screentime_api.dart`):
   - `FlutterScreentime` class: Main singleton with method channel ("flutter_screentime")
   - `ScreenTimeBlockScreenConfig`: Configuration object (title, message, colors, buttons) → serialized to Map
   - `ScreenTimeAuthorizationStatus` enum: notDetermined, denied, approved (mirrors platform status)
   - `SelectedAppsSummary`: Counts of selected apps/categories returned from picker

2. **iOS Native Layer** (`ios/Classes/FlutterScreentimePlugin.swift`):
   - Uses `FamilyControls` (iOS 16+) and `ManagedSettings` frameworks
   - Persists configuration and selections to `UserDefaults` (standard) and app-group shared defaults
   - **Key methods**: requestAuthorization → FamilyActivityPicker (SwiftUI) → applyStoredSelection → ManagedSettingsStore shielding
   - **Storage keys** (synced to app group):
     - `flutter_screentime.sharedContainerId`: App group ID
     - `flutter_screentime.blockScreenConfig`: Block screen UI config
     - `flutter_screentime.blockedSelection`: Serialized FamilyActivitySelection
     - `flutter_screentime.blockingEnabled`: Boolean flag
     - `flutter_screentime.blockedPackages`: List of package names (Android, stored for reference)

3. **Android Native Layer** (`android/src/main/kotlin/dev/iori/flutter_screentime/`):
   - `FlutterScreentimePlugin.kt`: Main plugin handler, orchestrates method calls
   - `BlockAppService.kt`: Foreground service that polls usage stats and shows overlay
     - Checks device lock, foreground app, and blocked packages every 500ms
     - Inflates overlay from `block_overlay.xml` layout with dynamic configuration
     - Handles overlay permissions (SYSTEM_ALERT_WINDOW) and usage stats access
   - `ScreenTimePreferences.kt`: SharedPreferences wrapper for configuration storage
   - `BootReceiver.kt`: Handles boot completion (auto-restart service if enabled)

### Plugin API (Dart)

```dart
const screenTime = FlutterScreentime();

// Authorization (iOS requires Family Controls entitlement)
await screenTime.checkAuthorization();           // Returns: notDetermined | denied | approved
await screenTime.requestAuthorization();         // Prompts user, returns status

// Configuration (persisted across restarts)
await screenTime.setSharedContainerId('group.your.app');  // iOS: required for extensions
await screenTime.configureBlockScreen(config);            // Both: UI customization

// Blocking
await screenTime.selectBlockedApps();            // iOS only: opens FamilyActivityPicker
await screenTime.setBlockedPackages(['com.x']);  // Android: explicitly set packages
await screenTime.startBlocking();                // Activates shielding/overlay
await screenTime.stopBlocking();                 // Deactivates, clears settings
```

### Example App

`example/lib/main.dart` demonstrates all plugin APIs with state management showing:
- Authorization status checks and requests
- Block screen configuration
- App selection (iOS)
- Start/stop blocking with error handling

## Build & Development Commands

### Plugin Package

```bash
# Install dependencies (both plugin and example)
flutter pub get

# Analyze code (lint checks with flutter_lints)
flutter analyze

# Run tests (unit tests for serialization and enums)
flutter test

# Run single test
flutter test test/flutter_screentime_test.dart -v
flutter test --name "ScreenTimeBlockScreenConfig serializes consistently"

# Build documentation (if pubspec.yaml enables doc generation)
# Note: No dartdoc setup currently, but can be added

# Format code
dart format lib/ test/
```

### Example App

```bash
cd example

# iOS
flutter run -v                    # Debug build, connected device or simulator
flutter run --release            # Release build

# Android
flutter run -v                   # Debug build
flutter run --release            # Release build
```

### iOS-Specific Notes

- **Xcode workspace**: `example/ios/Runner.xcworkspace` (must use workspace, not project, for CocoaPods)
- **Family Controls entitlement**: Already added to example target for testing
- **Extensions**: Example includes sample templates in `templates/ios/` (ShieldConfigurationExtension, DeviceActivityMonitorExtension)
  - To use: Copy `.sample` files, add targets in Xcode, share App Group with main app
  - See `doc/ios_extensions.md` for setup details

### Android-Specific Notes

- **Foreground service**: Requires `FOREGROUND_SERVICE` permission (added to manifest)
- **Overlay permission**: User must enable "Draw over other apps" for app (requested automatically in `requestAuthorization`)
- **Usage stats**: User must enable "App Usage Access" in Settings (requested in `requestAuthorization`)
- **Build system**: Gradle-based, Kotlin implementation
- **Target API**: Tested with modern Android versions; compatibility checks in code (Build.VERSION.SDK_INT guards)

## Key Files & Directories

- `pubspec.yaml`: Plugin metadata, dependencies (flutter, flutter_lints), iOS/Android platform definitions
- `lib/flutter_screentime.dart`: Public API entry point
- `lib/src/flutter_screentime_api.dart`: Core implementation (Dart serialization, enums, data classes)
- `ios/Classes/FlutterScreentimePlugin.swift`: iOS method channel handler, FamilyControls integration
- `android/src/main/kotlin/dev/iori/flutter_screentime/`: Android plugin implementation
- `test/flutter_screentime_test.dart`: Unit tests for data class serialization and enum parsing
- `example/lib/main.dart`: Full example demonstrating all plugin capabilities
- `analysis_options.yaml`: Linter configuration (uses package:flutter_lints/flutter.yaml)
- `doc/ios_extensions.md`: Setup guide for iOS Screen Time extensions
- `templates/ios/`: Sample extension implementations

## Dependencies

**Production**: flutter (SDK)
**Dev**: flutter_test (SDK), flutter_lints ^6.0.0

**Platform-specific native dependencies**:
- **iOS**: FamilyControls, ManagedSettings, SwiftUI (system frameworks, iOS 16+)
- **Android**: androidx.core:core (NotificationCompat), Android framework APIs

## Important Design Decisions

1. **iOS Extension Model**: Plugin does NOT create extensions; host app owns them. This allows custom Shield Content while plugin handles configuration storage and family controls bridge.

2. **Configuration Persistence**: All config (block screen UI, selected apps, blocking state) stored in UserDefaults (standard + app-group shared). Host iOS extensions read from shared group to render custom shield screens.

3. **Android No Native Picker**: Android lacks FamilyControls equivalent. Plugin uses `setBlockedPackages()` for explicit package blocking or blocks all launchable non-system apps if none specified.

4. **Overlay vs Shielding**: 
   - iOS uses native ManagedSettingsStore shielding (system-level)
   - Android uses foreground service + overlay (user-facing, can be dismissed)

## Common Tasks

### Adding a New Method to Plugin

1. Add method to `FlutterScreentime` class in `lib/src/flutter_screentime_api.dart` (Dart invocation)
2. Implement iOS handler in `FlutterScreentimePlugin.swift` (add case to switch statement)
3. Implement Android handler in `FlutterScreentimePlugin.kt` (add case to when statement)
4. Test on both platforms; add unit test if serialization involved

### Testing the Plugin

- Unit tests in `test/` cover Dart data class serialization and enum parsing
- No integration tests currently (would require platform channel mocking)
- Test with example app on real device or simulator for end-to-end validation

### iOS Extension Setup

1. Open `example/ios/Runner.xcworkspace` in Xcode
2. Add new target: File → New → Target → "Select a template..." → Search "Shield"
3. Copy sample code from `templates/ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift.sample`
4. Add App Group capability to both main app and extension
5. Set same group ID in both targets (e.g., `group.your.company.app`)
6. Call `setSharedContainerId('group.your.company.app')` in Dart before blocking

## Notes for Future Work

- No integration tests exist; consider platform channel mocking or emulator-based tests
- Android overlay is visual-only; no true app shielding (user can swipe through overlay)
- iOS requires iOS 16+ for FamilyControls; older iOS versions will fail authorization
- pubspec.yaml plugin configuration includes both iOS (pluginClass) and Android (package + pluginClass)

