import ManagedSettings
import Foundation
import os

private let kAppGroupID   = "group.com.ssssstudios.time4kids"
private let kNotification = "dev.iori.flutter_control_parental.shield_action"

private let log = Logger(
    subsystem: "com.ssssstudios.time4kids.ShieldActionExt",
    category: "ShieldAction"
)

class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(application:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(webDomain:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        log.info("🛡️ handle(category:) action=\(String(describing: action))")
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Apple no expone extensionContext ni ShieldActionResponse.open en este
            // tipo de extensión. La única vía es App Group + Darwin notification.
            // La app principal recibe la notificación y muestra una local push
            // para que el usuario la toque y abra la app.
            postShieldAction("primaryButton")
            log.info("🛡️ PRIMARY → event written + Darwin notification + .defer")
            completionHandler(.defer)

        case .secondaryButtonPressed:
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
        defaults.set(button, forKey: "flutter_control_parental.pendingShieldAction")
        defaults.synchronize()
        log.info("🛡️ ✅ Evento '\(button)' escrito en App Group")

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(kNotification as CFString),
            nil, nil, true
        )
        log.info("🛡️ Darwin notification posted")
    }
}
