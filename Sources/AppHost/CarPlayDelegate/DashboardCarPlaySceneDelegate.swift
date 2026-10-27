import CarPlay

final class DashboardCarPlaySceneDelegate: UIResponder {
    
    private var dashboardVC: OACarPlayMapDashboardViewController?
    private var mapVC: OAMapViewController?
    private var window: UIWindow?
    private var isForegroundScene = false
    private var applicationModeChangedObserver: OAAutoObserverProxy?
    private let launchHelper = CarPlaySceneLaunchHelper(sceneName: "DashboardCarPlaySceneDelegate")

    func sceneWillEnterForeground(_ scene: UIScene) {
        NSLog("[CarPlay] DashboardCarPlaySceneDelegate sceneWillEnterForeground")
        isForegroundScene = true
        configureScene()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NSLog("[CarPlay] DashboardCarPlaySceneDelegate sceneWillResignActive")
        launchHelper.cancel()
        stopObservingMapViewportSettings()
        isForegroundScene = false
    }

    private func configureScene() {
        stopObservingMapViewportSettings()
        launchHelper.run(isSceneConnected: window != nil, isSceneActive: { [weak self] in self?.isForegroundScene == true }) { [weak self] in
            guard let self, let mapVC = CarPlaySceneLaunchHelper.ensureMapViewController() else { return }
            self.mapVC = mapVC
            CarPlayService.shared.configure()
            dashboardVC = OACarPlayMapDashboardViewController(carPlay: mapVC)
            dashboardVC?.attachMapToWindow()
            window?.rootViewController = dashboardVC
            OARootViewController.instance()?.mapPanel.onCarPlayConnected()
            updateMapViewport()
            startObservingMapViewportSettings()
        }
    }
    
    private func startObservingMapViewportSettings() {
        stopObservingMapViewportSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(onProfileSettingSet(notification:)), name: NSNotification.Name(kNotificationSetProfileSetting), object: nil)
        applicationModeChangedObserver = OAAutoObserverProxy(self,
                                                             withHandler: #selector(onApplicationModeChanged),
                                                             andObserve: OsmAndApp.swiftInstance().applicationModeChangedObservable)
    }

    private func stopObservingMapViewportSettings() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kNotificationSetProfileSetting), object: nil)
        applicationModeChangedObserver?.detach()
        applicationModeChangedObserver = nil
    }

    private func updateMapViewport() {
        guard let mapVC else { return }
        let settings: OAAppSettings = OAAppSettings.sharedManager()
        let placement = settings.positionPlacementOnMap.get()
        var y: Double
        if placement == EOAPositionPlacement.auto.rawValue {
            y = settings.rotateMap.get() == ROTATE_MAP_BEARING ? mapCenterBottomY() : 1.0
        } else {
            y = placement == EOAPositionPlacement.center.rawValue ? 1.0 : mapCenterBottomY()
        }
        mapVC.setViewportForCarPlayScaleX(1.0, y: y)
    }

    private func mapCenterBottomY(bottomMargin: CGFloat = 60.0) -> CGFloat {
        guard let screenHeight = dashboardVC?.view.frame.height, screenHeight > 0 else {
            return 1.5
        }
        return 2.0 - (bottomMargin / (screenHeight / 2.0))
    }
    
    @objc private func onProfileSettingSet(notification: Notification) {
        let settings: OAAppSettings = OAAppSettings.sharedManager()
        guard let preferenceKeys = notification.userInfo?[kPreferenceKeysUserInfoKey] as? Set<String>,
              preferenceKeys.contains(settings.rotateMap.key) || preferenceKeys.contains(settings.positionPlacementOnMap.key) else {
            return
        }
        updateMapViewport()
    }

    @objc private func onApplicationModeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMapViewport()
        }
    }
}

extension DashboardCarPlaySceneDelegate: CPTemplateApplicationDashboardSceneDelegate {
    
    func templateApplicationDashboardScene(_ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene, didConnect dashboardController: CPDashboardController, to window: UIWindow) {
        NSLog("[CarPlay] DashboardCarPlaySceneDelegate didConnect")
        self.window = window
        dashboardController.shortcutButtons = createDashboardButtons(for: templateApplicationDashboardScene)
        if launchHelper.takeWaitingForConnection(), isForegroundScene {
            configureScene()
        }
    }
    
    func templateApplicationDashboardScene(_ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene, didDisconnect dashboardController: CPDashboardController, from window: UIWindow) {
        NSLog("[CarPlay] DashboardCarPlaySceneDelegate didDisconnect")
        CarPlayService.shared.disconnectScene(.dashboard)
        launchHelper.cancel()
        stopObservingMapViewportSettings()
        dashboardVC?.detachFromCarPlayWindow()
        dashboardVC = nil
        mapVC = nil
        self.window = nil
        OARootViewController.instance()?.mapPanel.detachFromCarPlayWindow()
    }
    
    private func createDashboardButtons(for scene: CPTemplateApplicationDashboardScene) -> [CPDashboardButton] {
        let actions: [CarPlayDashboardAction] = [.navigation, .search]
        
        return actions.map { action in
            let title: String
            let image: UIImage
            
            switch action {
            case .navigation:
                title = localizedString("shared_string_navigation")
                image = .icCarplayNavigation
            case .search:
                title = localizedString("address_search_desc")
                image = .icCarplaySearch
            }
            
            return CPDashboardButton(titleVariants: [title],
                                     subtitleVariants: [""],
                                     image: image) { _ in
                guard let url = action.url else { return }
                
                Task {
                    let success = await scene.open(url, options: nil)
                    if !success {
                        NSLog("[CarPlay] Failed to open URL: \(url)")
                    }
                }
            }
        }
    }
}
