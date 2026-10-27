import CarPlay

@available(iOS 15.4, *)
final class InstrumentClusterCarPlaySceneDelegate: UIResponder {

    private var clusterController: CPInstrumentClusterController?
    private var clusterViewController: UIViewController?
}

// MARK: - CPTemplateApplicationInstrumentClusterSceneDelegate

@available(iOS 15.4, *)
extension InstrumentClusterCarPlaySceneDelegate: CPTemplateApplicationInstrumentClusterSceneDelegate {

    func templateApplicationInstrumentClusterScene(_ templateApplicationInstrumentClusterScene: CPTemplateApplicationInstrumentClusterScene,
                                                   didConnect instrumentClusterController: CPInstrumentClusterController) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate didConnect")
        clusterController = instrumentClusterController
        instrumentClusterController.delegate = self
    }

    func templateApplicationInstrumentClusterScene(_ templateApplicationInstrumentClusterScene: CPTemplateApplicationInstrumentClusterScene,
                                                   didDisconnectInstrumentClusterController instrumentClusterController: CPInstrumentClusterController) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate didDisconnect")
        CarPlayService.shared.disconnectScene(.instrumentCluster)
        instrumentClusterController.delegate = nil
        clusterViewController = nil
        clusterController = nil
    }

    func contentStyleDidChange(_ contentStyle: UIUserInterfaceStyle) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate contentStyleDidChange \(contentStyle.rawValue)")
        clusterController?.instrumentClusterWindow?.overrideUserInterfaceStyle = contentStyle
    }
}

// MARK: - CPInstrumentClusterControllerDelegate

@available(iOS 15.4, *)
extension InstrumentClusterCarPlaySceneDelegate: CPInstrumentClusterControllerDelegate {

    func instrumentClusterControllerDidConnect(_ clusterWindow: UIWindow) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate window connected")
        // Placeholder until the cluster map is added
        let viewController = UIViewController()
        viewController.view.backgroundColor = .black
        clusterViewController = viewController
        clusterWindow.rootViewController = viewController
    }

    func instrumentClusterControllerDidDisconnectWindow(_ clusterWindow: UIWindow) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate window disconnected")
        clusterWindow.rootViewController = nil
        clusterViewController = nil
    }

    func instrumentClusterControllerDidZoom(in instrumentClusterController: CPInstrumentClusterController) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate zoom in")
    }

    func instrumentClusterControllerDidZoomOut(_ instrumentClusterController: CPInstrumentClusterController) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate zoom out")
    }

    func instrumentClusterController(_ instrumentClusterController: CPInstrumentClusterController,
                                     didChangeCompassSetting compassSetting: CPInstrumentClusterSetting) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate compass setting \(compassSetting.rawValue)")
    }

    func instrumentClusterController(_ instrumentClusterController: CPInstrumentClusterController,
                                     didChangeSpeedLimitSetting speedLimitSetting: CPInstrumentClusterSetting) {
        NSLog("[CarPlay] InstrumentClusterCarPlaySceneDelegate speed limit setting \(speedLimitSetting.rawValue)")
    }
}
