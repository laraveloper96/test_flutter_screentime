// ShieldConfigurationExtension.swift
// Copia como ShieldConfigurationExtension.swift en tu target de extensión.
// Requiere: App Group compartido, entitlement com.apple.developer.family-controls

import ManagedSettings
import ManagedSettingsUI
import UIKit

private let kAppGroupID = "group.dev.iori.flutterScreentimePluginTemplateIoriExample" // ⚠️ Reemplaza con tu App Group ID

@available(iOS 16.0, *)
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

  override func configuration(
    shielding application: Application
  ) -> ShieldConfiguration {
    buildConfiguration()
  }

  private func buildConfiguration() -> ShieldConfiguration {
    let defaults = UserDefaults(suiteName: kAppGroupID)

    // Opción A: leer configuración de texto/colores desde App Group
    let config = defaults?.dictionary(forKey: "flutter_screentime.blockScreenConfig")
    let title = config?["title"] as? String
    let subtitle = config?["subtitle"] as? String
    let primaryLabel = config?["primaryButtonLabel"] as? String
    let secondaryLabel = config?["secondaryButtonLabel"] as? String
    let primaryColorHex = config?["primaryButtonColorHex"] as? String
    let primaryTextColorHex = config?["primaryButtonTextColorHex"] as? String
    let bgColorHex = config?["backgroundColorHex"] as? String
    let blurStyleStr = config?["backgroundBlurStyle"] as? String

    // Opción B: intentar cargar ícono PNG personalizado desde App Group
    var icon: UIImage? = nil
    if let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: kAppGroupID
    ) {
      let iconURL = containerURL.appendingPathComponent("flutter_screentime_shield_icon.png")
      icon = UIImage(contentsOfFile: iconURL.path)
    }

    // Construir ShieldConfiguration
    let primaryButton: ShieldConfiguration.Label? = primaryLabel.map {
      .init(text: $0, color: UIColor(hex: primaryTextColorHex ?? "#FFFFFF") ?? .white)
    }
    let secondaryButton: ShieldConfiguration.Label? = secondaryLabel.map {
      .init(text: $0, color: .secondaryLabel)
    }

    let backgroundColor: UIColor? = UIColor(hex: bgColorHex ?? "#111827")

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
