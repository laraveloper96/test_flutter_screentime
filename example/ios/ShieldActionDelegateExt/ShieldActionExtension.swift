import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        switch action {
        case .primaryButtonPressed:
            let button = (action == .primaryButtonPressed) ? "primary" : "secondary"
            let url = URL(string: "flutter-screentime://shield-action?button=\(button)")!
            completionHandler(.open(url))
        case .secondaryButtonPressed:
            let button = (action == .secondaryButtonPressed) ? "primary" : "secondary"
            let url = URL(string: "flutter-screentime://shield-action?button=\(button)")!
            completionHandler(.open(url))
        @unknown default:
            fatalError()
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
}
