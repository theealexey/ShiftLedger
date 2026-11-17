import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appLock: AppLockController?
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        let appLock = AppLockController(window: window)
        self.appLock = appLock
        appLock.rootDidChange()
        let coordinator = AppCoordinator(window: window, appLock: appLock)

        self.window = window
        appCoordinator = coordinator
        coordinator.start()
    }

    func sceneDidBecomeActive(_ scene: UIScene) { appLock?.didBecomeActive() }

    func sceneWillResignActive(_ scene: UIScene) { appLock?.willResignActive() }

    func sceneDidEnterBackground(_ scene: UIScene) { appLock?.didEnterBackground() }

    func sceneDidDisconnect(_ scene: UIScene) {
        appLock?.didEnterBackground()
        appCoordinator?.stop()
        appCoordinator = nil
    }
}
