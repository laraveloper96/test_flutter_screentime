import ManagedSettings
import Foundation
import os

private let kAppGroupID   = "group.com.ssssstudios.time4kids"
private let kNotification = "dev.iori.flutter_screentime.shield_action"

private let log = Logger(
    subsystem: "com.ssssstudios.time4kids.ShieldActionExt",
    category: "ShieldAction"
)

class ShieldActionExtension: ShieldActionDelegate {

    // MARK: - App bloqueada directamente

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(application:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    // MARK: - Dominio web bloqueado

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(webDomain:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    // MARK: - Categoría bloqueada

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(category:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    // MARK: - Lógica compartida

    private func respond(
        to action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Escribe el evento en el App Group y notifica a la app principal.
            // La app principal escucha la Darwin notification, lee el evento
            // y emite al stream onShieldAction() → onPermissionRequest().
            // El shield se mantiene visible hasta que el padre apruebe o deniegue.
            postShieldAction("primaryButton")
            log.info("🛡️ PRIMARY → event written + Darwin notification + .defer")
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // Cierra el shield y vuelve a la pantalla anterior.
            log.info("🛡️ SECONDARY → .close")
            completionHandler(.close)

        @unknown default:
            log.warning("🛡️ @unknown default → .close")
            completionHandler(.close)
        }
    }

    private func postShieldAction(_ button: String) {
        guard let defaults = UserDefaults(suiteName: kAppGroupID) else {
            log.error("🛡️ ❌ No se puede acceder al App Group: \(kAppGroupID)")
            return
        }
        defaults.set(button, forKey: "flutter_screentime.pendingShieldAction")
        defaults.synchronize()
        log.info("🛡️ ✅ Evento '\(button)' escrito en App Group")

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(kNotification as CFString),
            nil, nil, true
        )
        log.info("🛡️ Darwin notification posted: \(kNotification)")
    }
}
