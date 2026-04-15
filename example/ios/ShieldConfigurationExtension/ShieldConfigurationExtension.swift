// ShieldConfigurationExtension.swift
import ManagedSettings
import ManagedSettingsUI
import UIKit
import os

private let kAppGroupID = "group.com.ssssstudios.time4kids"

private let log = Logger(
  subsystem: "com.ssssstudios.time4kids.ShieldConfigurationExtension",
  category: "ShieldConfig"
)

class ShieldConfigDataSource: ShieldConfigurationDataSource {

  override init() {
    super.init()
    log.info("🛡️ init() — proceso de extensión arrancó")
    // Escribe timestamp en UserDefaults del App Group para que la app Flutter
    // pueda confirmar que el proceso de extensión fue lanzado por iOS.
    if let defaults = UserDefaults(suiteName: kAppGroupID) {
      defaults.set(Date().timeIntervalSince1970, forKey: "flutter_screentime.extensionLastRun")
      defaults.set("init", forKey: "flutter_screentime.extensionLastTrigger")
      defaults.synchronize()
      log.info("🛡️ init() — timestamp escrito en App Group")
    } else {
      log.error("🛡️ init() — ❌ App Group no accesible desde extensión")
    }
  }

  override func configuration(
    shielding application: Application
  ) -> ShieldConfiguration {
    log.info("🛡️ [APP] configuration(shielding application:) called — bundleID=\(application.bundleIdentifier ?? "nil")")
    return buildConfiguration(trigger: "app:\(application.bundleIdentifier ?? "unknown")")
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    log.info("🛡️ [APP+CAT] configuration(shielding:in category:) called — bundleID=\(application.bundleIdentifier ?? "nil")")
    return buildConfiguration(trigger: "app-in-category:\(application.bundleIdentifier ?? "unknown")")
  }

  override func configuration(
    shielding webDomain: WebDomain
  ) -> ShieldConfiguration {
    log.info("🛡️ [WEB] configuration(shielding webDomain:) called — domain=\(webDomain.domain ?? "nil")")
    return buildConfiguration(trigger: "webDomain:\(webDomain.domain ?? "unknown")")
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    log.info("🛡️ [WEB+CAT] configuration(shielding webDomain:in category:) called — domain=\(webDomain.domain ?? "nil")")
    return buildConfiguration(trigger: "webDomain-in-category:\(webDomain.domain ?? "unknown")")
  }

  private func buildConfiguration(trigger: String) -> ShieldConfiguration {
    log.info("🛡️ buildConfiguration called — trigger=\(trigger)")

      // ⚠️ TEST: escribe un archivo de diagnóstico en el App Group para
    // confirmar desde la app Flutter si la extensión está corriendo.
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: kAppGroupID
    ) {
      let diagURL = containerURL.appendingPathComponent("shield_extension_ran.txt")
      let timestamp = Date().timeIntervalSince1970
      try? "trigger=\(trigger) ts=\(timestamp)".write(to: diagURL, atomically: true, encoding: .utf8)
      log.info("🛡️ ✍️ wrote diagnostic file to \(diagURL.path)")
    }

    let defaults = UserDefaults(suiteName: kAppGroupID)
    log.info("🛡️ UserDefaults(suiteName: \(kAppGroupID)) available=\(defaults != nil)")

    let allKeys = defaults?.dictionaryRepresentation().keys.filter { $0.hasPrefix("flutter_screentime") } ?? []
    log.info("🛡️ flutter_screentime keys in App Group: \(allKeys.sorted())")

    let config = defaults?.dictionary(forKey: "flutter_screentime.blockScreenConfig")
    log.info("🛡️ blockScreenConfig raw: \(String(describing: config))")

    let title = config?["title"] as? String
    let subtitle = config?["subtitle"] as? String
    let primaryLabel = config?["primaryButtonLabel"] as? String
    let secondaryLabel = config?["secondaryButtonLabel"] as? String
    let primaryColorHex = config?["primaryButtonColorHex"] as? String
    let primaryTextColorHex = config?["primaryButtonTextColorHex"] as? String
    let bgColorHex = config?["backgroundColorHex"] as? String
    let blurStyleStr = config?["backgroundBlurStyle"] as? String

    log.info("🛡️ parsed — title=\(title ?? "NIL"), subtitle=\(subtitle ?? "NIL"), bgColor=\(bgColorHex ?? "NIL"), primaryColor=\(primaryColorHex ?? "NIL"), blur=\(blurStyleStr ?? "NIL")")
    log.info("🛡️ parsed — primaryLabel=\(primaryLabel ?? "NIL"), secondaryLabel=\(secondaryLabel ?? "NIL")")

    var icon: UIImage? = nil
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: kAppGroupID
    ) {
      let iconURL = containerURL.appendingPathComponent("flutter_screentime_shield_icon.png")
      let iconExists = FileManager.default.fileExists(atPath: iconURL.path)
      icon = UIImage(contentsOfFile: iconURL.path)
      log.info("🛡️ App Group container=\(containerURL.path) — iconExists=\(iconExists) — iconLoaded=\(icon != nil)")
    } else {
      log.error("🛡️ ❌ Could NOT access App Group container '\(kAppGroupID)' — check entitlements")
    }

    let primaryButton: ShieldConfiguration.Label? = primaryLabel.map {
      .init(text: $0, color: UIColor(hex: primaryTextColorHex ?? "#FFFFFF") ?? .white)
    }
    let secondaryButton: ShieldConfiguration.Label? = secondaryLabel.map {
      .init(text: $0, color: .secondaryLabel)
    }

    let backgroundColor: UIColor? = UIColor(hex: bgColorHex ?? "#111827")

    log.info("🛡️ ✅ returning ShieldConfiguration — bgColor=\(bgColorHex ?? "#111827(fallback)") primaryBtnColor=\(primaryColorHex ?? "#3B82F6(fallback)") title=\(title ?? "nil(iOS default)") primaryLabel=\(primaryLabel ?? "nil(iOS default)")")

    return ShieldConfiguration(
      backgroundBlurStyle: blurStyle(from: blurStyleStr),
      backgroundColor: backgroundColor,
      icon: icon,
      title: title.map { .init(text: $0, color: .white) },
      subtitle: subtitle.map { .init(text: $0, color: .lightText) },
      primaryButtonLabel: primaryButton,
      primaryButtonBackgroundColor: UIColor(hex: primaryColorHex ?? "#3B82F6"),
      secondaryButtonLabel: secondaryButton
    )
  }

  private func blurStyle(from string: String?) -> UIBlurEffect.Style? {
    switch string {
    case "dark": return .dark
    case "light": return .light
    case "none": return nil
    default: return .dark
    }
  }
}

// MARK: - UIColor hex helper
private extension UIColor {
  convenience init?(hex: String?) {
    guard let hex = hex else { return nil }
    var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if h.hasPrefix("#") { h = String(h.dropFirst()) }
    guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
    self.init(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }
}
