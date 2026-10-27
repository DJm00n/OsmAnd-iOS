import CarPlay

@objc
protocol CarPlayActionDelegate: NSObjectProtocol {
    func showAlertWith(title: String, completion: (() -> Void)?, presentationFailure: (() -> Void)?)
    func showAlert(title: String, actions: [AlertActionConfig], presentationFailure: (() -> Void)?)
}

final class CarPlaySceneDelegate: UIResponder {
    
    private var carPlayMapController: OACarPlayMapViewController?
    private var carPlayDashboardController: OACarPlayDashboardInterfaceController?
    private var windowToAttach: CPWindow?
    private var carPlayInterfaceController: CPInterfaceController?
    private var isForegroundScene = false
    /// Starting with iOS 18.5 (CarPlay simulator), sceneWillEnterForeground can be called before didConnect;
    /// the helper remembers that and the scene is configured from didConnect.
    private let launchHelper = CarPlaySceneLaunchHelper(sceneName: "CarPlaySceneDelegate")
    /// Set on a new CarPlay connection only, so returning to OsmAnd from another CarPlay app keeps the map where the user left it.
    private var shouldCenterOnMyLocation = false
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        NSLog("[CarPlay] CarPlaySceneDelegate sceneWillEnterForeground")
        isForegroundScene = true
        configureScene()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        NSLog("[CarPlay] CarPlaySceneDelegate sceneWillResignActive")
        launchHelper.cancel()
        removeListeners()
        isForegroundScene = false
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              let action = CarPlayDashboardAction(url: url) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.handleDeepLink(action: action)
        }
    }
    
    private func handleDeepLink(action: CarPlayDashboardAction) {
        NSLog("[CarPlay] CarPlaySceneDelegate handling deep link action: \(action.rawValue)")
        
        switch action {
        case .search:
            carPlayDashboardController?.openSearch()
        case .navigation:
            carPlayDashboardController?.openNavigation()
        }
    }
    
    private func configureScene() {
        launchHelper.run(isSceneConnected: carPlayInterfaceController != nil && windowToAttach != nil,
                         isSceneActive: { [weak self] in self?.isForegroundScene == true }) { [weak self] in
            guard let self, let carPlayInterfaceController, let windowToAttach else { return }
            presentInCarPlay(interfaceController: carPlayInterfaceController, window: windowToAttach)
            CarPlayService.shared.configure()
        }
    }
    
    private func presentInCarPlay(interfaceController: CPInterfaceController, window: CPWindow) {
        if OAIAPHelper.sharedInstance().isCarPlayAvailable() {
            var mapVc = OARootViewController.instance()?.mapPanel.mapViewController
            if mapVc == nil {
                mapVc = OAMapViewController()
                OARootViewController.instance()?.mapPanel.setMap(mapVc)
            }
            if shouldCenterOnMyLocation {
                shouldCenterOnMyLocation = false
                centerOnMyLocation()
            }
            carPlayMapController = OACarPlayMapViewController(carPlay: window, mapViewController: mapVc)
            carPlayDashboardController = OACarPlayDashboardInterfaceController(interfaceController: interfaceController)
            carPlayDashboardController?.delegate = carPlayMapController
            carPlayMapController?.delegate = carPlayDashboardController
            window.rootViewController = carPlayMapController
            carPlayDashboardController?.present()
            OARootViewController.instance()?.mapPanel.onCarPlayConnected()
        } else {
            let vc = OACarPlayActiveViewController()
            vc.messageText = localizedString("carplay_available_in_sub_plans")
            vc.smallLogo = true
            let purchaseController = OACarPlayPurchaseViewController(carPlay: window, viewController: vc)
            window.rootViewController = purchaseController
            carPlayDashboardController = OACarPlayDashboardInterfaceController(interfaceController: interfaceController)
            carPlayDashboardController?.present()
            if let navigationController = OARootViewController.instance()?.navigationController {
                OAChoosePlanHelper.showChoosePlanScreen(with: OAFeature.carplay(), navController: navigationController)
            }
        }
        addListeners()
    }
    
    /// A drive starts from the car position, not from the last place viewed on the map.
    /// A calculated route still opens as a route overview: it moves the map and unlinks it again.
    private func centerOnMyLocation() {
        guard let app = OsmAndApp.swiftInstance(), app.locationServices?.denied != true else { return }
        app.mapMode = .positionTrack
    }
    
    private func addListeners() {
        guard let carPlayDashboardController else { return }
        let routingHelper = OARoutingHelper.sharedInstance()
        
        // Register as a route information listener
        if let infoListener = carPlayDashboardController as? OARouteInformationListener {
            routingHelper.add(infoListener)
        }
        
        // Register for route calculation progress callbacks
        if let progressListener = carPlayDashboardController as? OARouteCalculationProgressCallback {
            routingHelper.add(progressListener)
        }
    }
    
    private func removeListeners() {
        guard let carPlayDashboardController else { return }
        let routingHelper = OARoutingHelper.sharedInstance()
        
        // Unregister as a route information listener
        if let infoListener = carPlayDashboardController as? OARouteInformationListener {
            routingHelper.remove(infoListener)
        }
        
        // Unregister route calculation progress callbacks
        if let progressListener = carPlayDashboardController as? OARouteCalculationProgressCallback {
            routingHelper.remove(progressListener)
        }
    }
}

extension CarPlaySceneDelegate: CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) {
        NSLog("[CarPlay] CarPlaySceneDelegate didConnect")
        
        windowToAttach = window
        carPlayInterfaceController = interfaceController
        shouldCenterOnMyLocation = true
        if launchHelper.takeWaitingForConnection(), isForegroundScene {
            configureScene()
        }
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        NSLog("[CarPlay] CarPlaySceneDelegate didDisconnect")
        
        CarPlayService.shared.disconnectScene(.app)
        guard let mapPanel = OARootViewController.instance()?.mapPanel else {
            NSLog("[CarPlay] CarPlaySceneDelegate rootViewController mapPanel is nil")
            return
        }
        
        mapPanel.onCarPlayDisconnected { [weak self] in
            guard let self else { return }
            NSLog("[CarPlay] CarPlaySceneDelegate onCarPlayDisconnected")
            carPlayMapController?.detachFromCarPlayWindow()
            carPlayDashboardController = nil
            carPlayMapController?.navigationController?.popViewController(animated: true)
            window.rootViewController = nil
            carPlayMapController = nil
            windowToAttach = nil
            carPlayInterfaceController = nil
        }
    }
}

// MARK: - OAWidgetListener

extension CarPlaySceneDelegate: OAWidgetListener {
    func widgetChanged(_ widget: OABaseWidgetView?) {
        if widget is SpeedometerView {
            carPlayMapController?.configureSpeedometer()
        }
    }
    
    func widgetVisibilityChanged(_ widget: OABaseWidgetView, visible: Bool) { }
    
    func widgetClicked(_ widget: OABaseWidgetView) { }
}

extension CarPlaySceneDelegate: CarPlayActionDelegate {
    func showAlertWith(title: String, completion: (() -> Void)? = nil, presentationFailure: (() -> Void)? = nil) {
        guard let carPlayInterfaceController else {
            presentationFailure?()
            return
        }
        
        let okAction = CPAlertAction(title: localizedString("shared_string_ok"), style: .default) { _ in
            carPlayInterfaceController.dismissTemplate(animated: true) { _, _ in
                completion?()
            }
        }
        let alertTemplate = CPAlertTemplate(titleVariants: [title], actions: [okAction])
        
        Task { @MainActor in
            do {
                try await carPlayInterfaceController.presentTemplate(alertTemplate, animated: true)
            } catch {
                presentationFailure?()
            }
        }
    }
    
    func showAlert(title: String, actions: [AlertActionConfig], presentationFailure: (() -> Void)? = nil) {
        guard let carPlayInterfaceController else {
            presentationFailure?()
            return
        }
        
        let cpActions = actions.map { config in
            CPAlertAction(title: config.title, style: config.carPlayAlertStyle) { _ in
                carPlayInterfaceController.dismissTemplate(animated: true) { _, _ in
                    config.handler?()
                }
            }
        }
        
        let alertTemplate = CPAlertTemplate(titleVariants: [title], actions: cpActions)
        
        Task { @MainActor in
            do {
                try await carPlayInterfaceController.presentTemplate(alertTemplate, animated: true)
            } catch {
                presentationFailure?()
            }
        }
    }
}
