import Flutter
import UIKit
import os

private let log = Logger(
    subsystem: "com.ssssstudios.time4kids",
    category: "SceneDelegate"
)

class SceneDelegate: FlutterSceneDelegate {

    /// En apps con scene lifecycle (iOS 13+), los deep links llegan aquí —
    /// no a application(_:open:options:) del AppDelegate.
    /// Reenviamos manualmente al AppDelegate para que FlutterAppDelegate
    /// lo propague a los plugins registrados (incluido FlutterScreentimePlugin).
    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        super.scene(scene, openURLContexts: URLContexts)

        guard let url = URLContexts.first?.url else {
            log.warning("🔗 scene(openURLContexts:) — sin URL")
            return
        }

        log.info("🔗 scene(openURLContexts:) — url=\(url.absoluteString)")

        let app = UIApplication.shared
        _ = app.delegate?.application?(app, open: url, options: [:])
    }
}
