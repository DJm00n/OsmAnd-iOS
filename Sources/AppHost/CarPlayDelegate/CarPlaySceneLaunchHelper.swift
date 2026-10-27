import UIKit

/// Waits until the app root and the map are ready, then hands the map to a secondary CarPlay scene.
/// Shared by the Dashboard and Instrument Cluster scene delegates.
final class CarPlaySceneLaunchHelper {
    
    private let sceneName: String
    private var isSceneActive: (() -> Bool)?
    private var onReady: ((OAMapViewController) -> Void)?
    
    init(sceneName: String) {
        self.sceneName = sceneName
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Calls `onReady` right away if the app is already initialized,
    /// otherwise as soon as the app reaches `setupRoot` while `isSceneActive` returns `true`.
    func run(isSceneActive: @escaping () -> Bool, onReady: @escaping (OAMapViewController) -> Void) {
        cancel()
        guard let appDelegate = UIApplication.shared.delegate as? OAAppDelegate else { return }
        appDelegate.initialize()
        
        if case .setupRoot = appDelegate.appLaunchEvent {
            // if CarPlay was open without a connected device
            if appDelegate.rootViewController == nil {
                appDelegate.rootViewController = OARootViewController()
            }
            var mapVC = OARootViewController.instance()?.mapPanel.mapViewController
            if mapVC == nil {
                mapVC = OAMapViewController()
                OARootViewController.instance()?.mapPanel.setMap(mapVC)
            }
            if let mapVC {
                onReady(mapVC)
            }
        } else {
            // if the scene becomes active before the root view controller is set
            self.isSceneActive = isSceneActive
            self.onReady = onReady
            NotificationCenter.default.addObserver(self, selector: #selector(appInitEvent(notification:)), name: NSNotification.Name.OALaunchUpdateState, object: nil)
        }
    }
    
    func cancel() {
        NotificationCenter.default.removeObserver(self)
        isSceneActive = nil
        onReady = nil
    }
    
    @objc private func appInitEvent(notification: Notification) {
        NSLog("[CarPlay] \(sceneName) appInitEventConfigureScene")
        guard let userInfo = notification.userInfo,
              let item = userInfo["event"] as? Int,
              let event = AppLaunchEvent(rawValue: item) else { return }
        if case .setupRoot = event {
            guard let isSceneActive, let onReady, isSceneActive() else { return }
            NSLog("[CarPlay] \(sceneName) appInitEventConfigureScene success")
            run(isSceneActive: isSceneActive, onReady: onReady)
        }
    }
}
