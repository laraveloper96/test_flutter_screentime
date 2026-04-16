import DeviceActivity
import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit
import os

private let pluginLog = Logger(
  subsystem: "dev.iori.flutterScreentimePluginTemplateIoriExample",
  category: "FlutterScreentime"
)

private enum StorageKey {
  static let sharedContainerId = "flutter_screentime.sharedContainerId"
  static let blockScreenConfig = "flutter_screentime.blockScreenConfig"
  static let blockedPackages = "flutter_screentime.blockedPackages"
  static let blockedSelection = "flutter_screentime.blockedSelection"
  static let blockingEnabled = "flutter_screentime.blockingEnabled"
  static let activitySchedule = "flutter_screentime.activitySchedule"
  static let dailyTimeLimit = "flutter_screentime.dailyTimeLimit"
  static let shieldIcon = "flutter_screentime.shieldIcon"
  static let lastActivityEvent = "flutter_screentime.lastActivityEvent"
}

private let kActivityEventNotification = "dev.iori.flutter_screentime.activity_event"

private final class BlockedAppsPickerModel: ObservableObject {
  @Published var selection: FamilyActivitySelection

  init(selection: FamilyActivitySelection) {
    self.selection = selection
  }
}

@available(iOS 16.0, *)
private struct BlockedAppsPickerView: View {
  @ObservedObject var model: BlockedAppsPickerModel
  let onCancel: () -> Void
  let onSave: (FamilyActivitySelection) -> Void

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $model.selection)
        .navigationTitle("Select Apps")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              onSave(model.selection)
            }
          }
        }
    }
  }
}

fileprivate class ShieldActionStreamHandler: NSObject, FlutterStreamHandler {
  var eventSink: FlutterEventSink?
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

fileprivate class ActivityEventStreamHandler: NSObject, FlutterStreamHandler {
  var eventSink: FlutterEventSink?
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

public final class FlutterScreentimePlugin: NSObject, FlutterPlugin {
  private let store = ManagedSettingsStore()
  fileprivate let shieldActionHandler = ShieldActionStreamHandler()
  fileprivate let activityEventHandler = ActivityEventStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_screentime",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterScreentimePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let shieldActionChannel = FlutterEventChannel(
      name: "flutter_screentime/shield_action",
      binaryMessenger: registrar.messenger()
    )
    shieldActionChannel.setStreamHandler(instance.shieldActionHandler)

    let activityEventChannel = FlutterEventChannel(
      name: "flutter_screentime/activity_event",
      binaryMessenger: registrar.messenger()
    )
    activityEventChannel.setStreamHandler(instance.activityEventHandler)

    registrar.addApplicationDelegate(instance)
    instance.setupNotificationObservers()
  }

  private func setupNotificationObservers() {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passUnretained(self).toOpaque()

    CFNotificationCenterAddObserver(
      center,
      observer,
      { (_, observer, name, _, _) in
        guard let observer = observer else { return }
        let plugin = Unmanaged<FlutterScreentimePlugin>.fromOpaque(observer).takeUnretainedValue()
        plugin.handleActivityEventNotification()
      },
      kActivityEventNotification as CFString,
      nil,
      .deliverImmediately
    )
  }

  private func handleActivityEventNotification() {
    pluginLog.info("📱 Received Darwin Notification: \(kActivityEventNotification)")
    guard let shared = sharedDefaults() else {
      pluginLog.error("📱 Notification received but sharedDefaults is nil")
      return
    }
    
    guard let eventMap = shared.dictionary(forKey: StorageKey.lastActivityEvent) else {
      pluginLog.warning("📱 Notification received but no event found in App Group for key: \(StorageKey.lastActivityEvent)")
      return
    }
    
    pluginLog.info("📱 Bridge: Activity Event found: \(String(describing: eventMap))")
    shared.removeObject(forKey: StorageKey.lastActivityEvent)
    shared.synchronize()

    DispatchQueue.main.async {
      self.emitActivityEvent(eventMap)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    // MARK: - FamilyControls
    case "checkAuthorization":
      result(currentAuthorizationStatus())
    case "requestAuthorization":
      requestAuthorization(result: result)
    case "revokeAuthorization":
      revokeAuthorization(result: result)
    case "selectBlockedApps":
      presentBlockedAppsPicker(result: result)
    case "getSelectedAppsSummary":
      result(selectedAppsSummaryMap())

    // MARK: - ManagedSettings
    case "setSharedContainerId":
      guard let appGroupId = call.arguments as? String, !appGroupId.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "Expected a non-empty app group id.", details: nil))
        return
      }
      UserDefaults.standard.set(appGroupId, forKey: StorageKey.sharedContainerId)
      synchronizeStoredValuesToSharedDefaults()
      result(nil)
    case "startBlocking":
      applyStoredSelection(result: result)
    case "stopBlocking":
      persist(false, forKey: StorageKey.blockingEnabled)
      store.clearAllSettings()
      result(nil)
    case "grantTemporaryAccess":
      guard let seconds = call.arguments as? Int, seconds > 0 else {
        result(FlutterError(code: "invalid_args", message: "Expected positive seconds.", details: nil))
        return
      }
      grantTemporaryAccess(seconds: seconds, result: result)
    case "getBlockingStatus":
      let isEnabled = storedValue(forKey: StorageKey.blockingEnabled) as? Bool ?? false
      result(isEnabled)

    // MARK: - DeviceActivity
    case "setSchedule":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Expected schedule map.", details: nil))
        return
      }
      setSchedule(args: args, result: result)
    case "getSchedule":
      result(storedScheduleMap())
    case "clearSchedule":
      clearSchedule(result: result)
    case "startMonitoring":
      startMonitoring(result: result)
    case "stopMonitoring":
      stopMonitoring(result: result)

    // MARK: - ShieldExtension
    case "configureBlockScreen", "configureShield":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Expected a configuration map.", details: nil))
        return
      }
      persist(arguments, forKey: StorageKey.blockScreenConfig)
      result(nil)
    case "setShieldIcon":
      guard let iconData = (call.arguments as? FlutterStandardTypedData)?.data else {
        result(FlutterError(code: "invalid_args", message: "Expected PNG bytes.", details: nil))
        return
      }
      saveShieldIcon(data: iconData, result: result)

    // MARK: - Diagnostics
    case "getExtensionDiagnostic":
      result(readExtensionDiagnostic())

    // MARK: - Legacy / Android-only
    case "setBlockedPackages":
      guard let blockedPackages = call.arguments as? [String] else {
        result(FlutterError(code: "invalid_args", message: "Expected a list of package names.", details: nil))
        return
      }
      persist(blockedPackages, forKey: StorageKey.blockedPackages)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FamilyControls private methods

  private func currentAuthorizationStatus() -> String {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .approved:
      return "approved"
    case .denied:
      return "denied"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "notDetermined"
    }
  }

  private func requestAuthorization(result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        result(self.currentAuthorizationStatus())
      } catch {
        result(FlutterError(
          code: "authorization_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
  }

  private func revokeAuthorization(result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AuthorizationCenter.shared.revokeAuthorization(completionHandler: { _ in })
        self.store.clearAllSettings()
        if #available(iOS 16.0, *) {
          DeviceActivityCenter().stopMonitoring()
        }
        let keysToRemove = [
          StorageKey.blockScreenConfig,
          StorageKey.blockedPackages,
          StorageKey.blockedSelection,
          StorageKey.blockingEnabled,
          StorageKey.activitySchedule,
        ]
        keysToRemove.forEach { key in
          UserDefaults.standard.removeObject(forKey: key)
          self.sharedDefaults()?.removeObject(forKey: key)
        }
        result(nil)
      } catch {
        result(FlutterError(code: "revoke_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func presentBlockedAppsPicker(result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "FamilyControls requires iOS 16 or later.", details: nil))
      return
    }

    guard let presenter = topViewController() else {
      result(FlutterError(code: "no_presenter", message: "No presenter was available for the FamilyActivityPicker.", details: nil))
      return
    }

    let model = BlockedAppsPickerModel(selection: storedSelection())
    let hostingController = UIHostingController(
      rootView: BlockedAppsPickerView(
        model: model,
        onCancel: { [weak presenter] in
          presenter?.dismiss(animated: true)
          result(FlutterError(code: "cancelled", message: "Selection was cancelled.", details: nil))
        },
        onSave: { [weak self, weak presenter] selection in
          guard let self else { return }
          presenter?.dismiss(animated: true)
          self.persist(selectionData(from: selection), forKey: StorageKey.blockedSelection)
          result(self.selectionSummary(selection))
        }
      )
    )
    hostingController.modalPresentationStyle = .fullScreen
    hostingController.isModalInPresentation = true
    presenter.present(hostingController, animated: true)
  }

  private func selectedAppsSummaryMap() -> [String: Int] {
    let selection = storedSelection()
    return [
      "applicationCount": selection.applicationTokens.count,
      "categoryCount": selection.categoryTokens.count,
      "webDomainCount": selection.webDomainTokens.count,
    ]
  }

  private func storedSelection() -> FamilyActivitySelection {
    guard
      let data = storedValue(forKey: StorageKey.blockedSelection) as? Data,
      let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else {
      return FamilyActivitySelection()
    }
    return selection
  }

  private func selectionData(from selection: FamilyActivitySelection) -> Data? {
    try? PropertyListEncoder().encode(selection)
  }

  private func selectionSummary(_ selection: FamilyActivitySelection) -> [String: Int] {
    [
      "applicationCount": selection.applicationTokens.count,
      "categoryCount": selection.categoryTokens.count,
      "webDomainCount": selection.webDomainTokens.count,
    ]
  }

  // MARK: - ManagedSettings private methods

  private func applyStoredSelection(result: FlutterResult) {
    let selection = storedSelection()
    let hasSelection = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    guard hasSelection else {
      result(FlutterError(
        code: "missing_selection",
        message: "Call selectBlockedApps before startBlocking on iOS.",
        details: nil
      ))
      return
    }

    persist(true, forKey: StorageKey.blockingEnabled)
    let appCount = selection.applicationTokens.count
    let catCount = selection.categoryTokens.count
    pluginLog.info("📱 startBlocking: shielding \(appCount) apps, \(catCount) categories")
    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
    pluginLog.info("📱 ManagedSettingsStore shield applied — store=\(String(describing: self.store))")
    result(nil)
  }

  private func grantTemporaryAccess(seconds: Int, result: FlutterResult) {
    pluginLog.info("📱 grantTemporaryAccess: desbloqueando por \(seconds) segundos")
    store.clearAllSettings()
    result(nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) { [weak self] in
      guard let self else { return }
      let isEnabled = self.storedValue(forKey: StorageKey.blockingEnabled) as? Bool ?? false
      guard isEnabled else {
        self.pluginLog.info("📱 grantTemporaryAccess: bloqueo fue desactivado manualmente, no se reactiva")
        return
      }
      self.pluginLog.info("📱 grantTemporaryAccess: reactivando bloqueo después de \(seconds) segundos")
      let selection = self.storedSelection()
      self.store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
      self.store.shield.applicationCategories = selection.categoryTokens.isEmpty
        ? nil
        : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
    }
  }

  // MARK: - DeviceActivity private methods

  private func setSchedule(args: [String: Any], result: FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "DeviceActivity requires iOS 16+.", details: nil))
      return
    }
    persist(args, forKey: StorageKey.activitySchedule)
    startMonitoringWithArgs(args, result: result)
  }

  @available(iOS 16.0, *)
  private func startMonitoringWithArgs(_ args: [String: Any], result: FlutterResult) {
    let center = DeviceActivityCenter()
    let startHour = args["startHour"] as? Int ?? 0
    let startMinute = args["startMinute"] as? Int ?? 0
    let endHour = args["endHour"] as? Int ?? 23
    let endMinute = args["endMinute"] as? Int ?? 59
    let dailySeconds = args["dailyTimeLimitSeconds"] as? Int

    let schedule = DeviceActivitySchedule(
      intervalStart: DateComponents(hour: startHour, minute: startMinute),
      intervalEnd: DateComponents(hour: endHour, minute: endMinute),
      repeats: true,
      warningTime: nil
    )

    var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
    if let seconds = dailySeconds {
      let threshold = DateComponents(second: seconds)
      events[DeviceActivityEvent.Name("flutter_screentime.dailyLimit")] = DeviceActivityEvent(
        threshold: threshold
      )
    }

    do {
      try center.startMonitoring(
        DeviceActivityName("flutter_screentime.schedule"),
        during: schedule,
        events: events
      )
      result(nil)
    } catch {
      result(FlutterError(code: "monitoring_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func storedScheduleMap() -> [String: Any]? {
    storedValue(forKey: StorageKey.activitySchedule) as? [String: Any]
  }

  private func clearSchedule(result: FlutterResult) {
    guard #available(iOS 16.0, *) else {
      persist(nil, forKey: StorageKey.activitySchedule)
      result(nil)
      return
    }
    DeviceActivityCenter().stopMonitoring([DeviceActivityName("flutter_screentime.schedule")])
    persist(nil, forKey: StorageKey.activitySchedule)
    result(nil)
  }

  private func startMonitoring(result: FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "DeviceActivity requires iOS 16+.", details: nil))
      return
    }
    if let storedArgs = storedValue(forKey: StorageKey.activitySchedule) as? [String: Any] {
      startMonitoringWithArgs(storedArgs, result: result)
    } else {
      result(FlutterError(code: "no_schedule", message: "No schedule stored. Call setSchedule first.", details: nil))
    }
  }

  private func stopMonitoring(result: FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(nil)
      return
    }
    DeviceActivityCenter().stopMonitoring()
    result(nil)
  }

  // MARK: - ShieldExtension private methods

  private func saveShieldIcon(data: Data, result: FlutterResult) {
    guard let appGroupId = UserDefaults.standard.string(forKey: StorageKey.sharedContainerId),
          let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
      result(FlutterError(code: "no_app_group", message: "Set sharedContainerId before calling setShieldIcon.", details: nil))
      return
    }
    let iconURL = containerURL.appendingPathComponent("flutter_screentime_shield_icon.png")
    do {
      try data.write(to: iconURL)
      result(nil)
    } catch {
      result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func readExtensionDiagnostic() -> String {
    guard let appGroupId = UserDefaults.standard.string(forKey: StorageKey.sharedContainerId) else {
      return "❌ sharedContainerId no configurado — presiona 'Guardar App Group ID' primero"
    }
    guard let shared = UserDefaults(suiteName: appGroupId) else {
      return "❌ No se puede acceder al App Group '\(appGroupId)'"
    }

    let ts = shared.double(forKey: "flutter_screentime.extensionLastRun")
    let trigger = shared.string(forKey: "flutter_screentime.extensionLastTrigger") ?? "?"
    let configExists = shared.dictionary(forKey: "flutter_screentime.blockScreenConfig") != nil

    if ts > 0 {
      let date = Date(timeIntervalSince1970: ts)
      let fmt = DateFormatter()
      fmt.dateFormat = "HH:mm:ss"
      return "✅ Extensión corrió a las \(fmt.string(from: date)) — trigger=\(trigger) — config=\(configExists ? "presente" : "AUSENTE")"
    } else {
      return "❌ Extensión NUNCA corrió — ts=0 — config en AppGroup=\(configExists)"
    }
  }

  func emitShieldAction(_ action: String) {
    shieldActionHandler.eventSink?(action)
  }

  func emitActivityEvent(_ event: [String: Any]) {
    activityEventHandler.eventSink?(event)
  }

  // MARK: - Storage helpers

  private func persist(_ value: Any?, forKey key: String) {
    let appGroupId = UserDefaults.standard.string(forKey: StorageKey.sharedContainerId)
    let shared = sharedDefaults()
    pluginLog.info("📱 persist key=\(key) — appGroupId=\(appGroupId ?? "NOT SET") — sharedDefaults available=\(shared != nil)")

    if let sanitizedValue = value.flatMap({ sanitize($0) }) {
      UserDefaults.standard.set(sanitizedValue, forKey: key)
      if let shared {
        shared.set(sanitizedValue, forKey: key)
        shared.synchronize()
        pluginLog.info("📱 ✅ Written to App Group for key=\(key)")
      } else {
        pluginLog.error("📱 ❌ Could NOT write to App Group (nil) for key=\(key)")
      }
    } else {
      UserDefaults.standard.removeObject(forKey: key)
      sharedDefaults()?.removeObject(forKey: key)
    }
  }

  private func sanitize(_ value: Any) -> Any? {
    if value is NSNull {
      return nil
    }
    if let dict = value as? [String: Any] {
      var sanitized = [String: Any]()
      for (k, v) in dict {
        if let sv = sanitize(v) {
          sanitized[k] = sv
        }
      }
      return sanitized
    }
    if let array = value as? [Any] {
      return array.compactMap { sanitize($0) }
    }
    return value
  }

  private func storedValue(forKey key: String) -> Any? {
    sharedDefaults()?.object(forKey: key) ?? UserDefaults.standard.object(forKey: key)
  }

  private func sharedDefaults() -> UserDefaults? {
    guard let appGroupId = UserDefaults.standard.string(forKey: StorageKey.sharedContainerId) else {
      return nil
    }
    return UserDefaults(suiteName: appGroupId)
  }

  private func synchronizeStoredValuesToSharedDefaults() {
    guard let sharedDefaults = sharedDefaults() else {
      return
    }

    [
      StorageKey.blockScreenConfig,
      StorageKey.blockedPackages,
      StorageKey.blockedSelection,
      StorageKey.blockingEnabled,
      StorageKey.activitySchedule,
    ].forEach { key in
      if let value = UserDefaults.standard.object(forKey: key) {
        sharedDefaults.set(value, forKey: key)
      }
    }
  }

  // MARK: - UI helpers

  private func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let baseController = base ?? UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController

    if let navigationController = baseController as? UINavigationController {
      return topViewController(base: navigationController.visibleViewController)
    }

    if let tabBarController = baseController as? UITabBarController,
       let selectedViewController = tabBarController.selectedViewController {
      return topViewController(base: selectedViewController)
    }

    if let presentedViewController = baseController?.presentedViewController {
      return topViewController(base: presentedViewController)
    }

    return baseController
  }
}

// MARK: - URL scheme handler (ShieldActionExtension deep link)

extension FlutterScreentimePlugin {
  public func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    pluginLog.info("📱 application(open:) called with URL: \(url.absoluteString)")
    
    guard url.scheme == "flutter-screentime",
          url.host == "shield-action",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let buttonParam = components.queryItems?.first(where: { $0.name == "button" })?.value
    else {
      pluginLog.warning("📱 URL didn't match expected pattern (scheme=flutter-screentime, host=shield-action)")
      return false
    }
    
    let action = buttonParam == "primary" ? "primaryButton" : "secondaryButton"
    pluginLog.info("📱 Emitting ShieldAction: \(action)")
    emitShieldAction(action)
    return true
  }
}
