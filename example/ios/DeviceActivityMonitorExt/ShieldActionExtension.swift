// DeviceActivityMonitorExtension.swift
// Copia este archivo como DeviceActivityMonitorExtension.swift en tu target de extensión.
// Requiere:
//   - Target de tipo "Device Activity Monitor Extension" en Xcode
//   - App Group compartido con la app principal
//   - Entitlement com.apple.developer.family-controls en ambos targets

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// Nombre del App Group — debe coincidir con el configurado en la app principal
// via ManagedSettings.setSharedContainerId()
private let kAppGroupID = "group.com.ssssstudios.time4kids"

private let store = ManagedSettingsStore()

@available(iOS 16.0, *)
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

  // MARK: - Interval Events

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    emitEvent(type: "intervalDidStart", activityName: activity.rawValue)
    // Para "temporary_access" el inicio significa que el acceso está activo → no aplicamos escudo.
    // Solo aplicamos al iniciar ventanas de horario regulares.
    if activity.rawValue != "flutter_screentime.temporary_access" {
      applyBlocking()
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    emitEvent(type: "intervalDidEnd", activityName: activity.rawValue)

    if activity.rawValue == "flutter_screentime.temporary_access" {
      // El periodo de acceso temporal expiró → re-aplica el escudo si el bloqueo sigue activo
      let isEnabled = UserDefaults(suiteName: kAppGroupID)?.bool(forKey: "flutter_screentime.blockingEnabled") ?? false
      if isEnabled {
        applyBlocking()
      }
    } else {
      // Fin de una ventana de horario regular → limpia el escudo
      store.clearAllSettings()
    }
  }

  // MARK: - Threshold Events

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    applyBlocking()
    emitEvent(type: "thresholdReached", activityName: activity.rawValue)
  }

  // MARK: - Private helpers

  private func applyBlocking() {
    guard let sharedDefaults = UserDefaults(suiteName: kAppGroupID) else { return }

    guard
      let data = sharedDefaults.data(forKey: "flutter_screentime.blockedSelection"),
      let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    else {
      return
    }

    if !selection.applicationTokens.isEmpty {
      store.shield.applications = selection.applicationTokens
    }
    if !selection.categoryTokens.isEmpty {
      store.shield.applicationCategories = .specific(selection.categoryTokens)
    }
    if !selection.webDomainTokens.isEmpty {
      store.shield.webDomains = selection.webDomainTokens
    }
  }

  private func emitEvent(type: String, activityName: String) {
    guard let sharedDefaults = UserDefaults(suiteName: kAppGroupID) else { return }

    let event: [String: Any] = [
      "type": type,
      "activityName": activityName,
      "timestamp": Date().timeIntervalSince1970,
    ]
    sharedDefaults.set(event, forKey: "flutter_screentime.lastActivityEvent")
    sharedDefaults.synchronize()

    // Notifica a la app principal via Darwin notification
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName("flutter_screentime.activityEvent" as CFString),
      nil, nil, true
    )
  }
}
