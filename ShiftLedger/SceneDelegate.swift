import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var startupTask: Task<Void, Never>?
    private var coreDataStack: CoreDataStack?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.rootViewController = makeLoadingViewController()
        window.makeKeyAndVisible()
        startStartup()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        startupTask?.cancel()
        startupTask = nil
        coreDataStack = nil
    }

    private func startStartup() {
        startupTask?.cancel()

        let loadingViewController = makeLoadingViewController()
        window?.rootViewController = loadingViewController

        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let stack = try await CoreDataStack.load()
                try Task.checkCancellation()

                let jobStorage = JobStorage(stack: stack)
                let shiftStorage = ShiftStorage(stack: stack)
                let job = try jobStorage.load()

                try Task.checkCancellation()
                self.coreDataStack = stack

                if let job {
                    let addShiftViewController = AddShiftAssembly.make(
                        job: job,
                        shiftStorage: shiftStorage
                    )
                    let navigationController = UINavigationController(
                        rootViewController: addShiftViewController
                    )
                    try Task.checkCancellation()
                    self.window?.rootViewController = navigationController
                } else {
                    let navigationController = makeOnboardingNavigationController(
                        jobStorage: jobStorage,
                        shiftStorage: shiftStorage
                    )
                    navigationController.setNavigationBarHidden(true, animated: false)
                    try Task.checkCancellation()
                    self.window?.rootViewController = navigationController
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }
                presentStartupError()
            }
        }
    }

    private func makeLoadingViewController() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        return viewController
    }

    private func makeOnboardingNavigationController(
        jobStorage: JobStorage,
        shiftStorage: ShiftStorage
    ) -> UINavigationController {
        let navigationController = UINavigationController()
        let startViewController = JobSetupAssembly.makeStart(
            initialCurrencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "USD",
            initialTimeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )

        startViewController.onContinue = { [weak navigationController] draft in
            guard let navigationController else { return }

            let payPeriodViewController = JobSetupAssembly.makePayPeriod(draft: draft)
            payPeriodViewController.onBack = { [weak navigationController] in
                navigationController?.popViewController(animated: true)
            }
            payPeriodViewController.onContinue = { [weak navigationController] draft in
                guard let navigationController else { return }

                let reviewViewController = JobSetupAssembly.makeReview(
                    draft: draft,
                    jobStorage: jobStorage
                )
                reviewViewController.onBack = { [weak navigationController] in
                    navigationController?.popViewController(animated: true)
                }
                reviewViewController.onFinished = { [weak navigationController] job in
                    guard let navigationController else { return }

                    let addShiftViewController = AddShiftAssembly.make(
                        job: job,
                        shiftStorage: shiftStorage
                    )
                    navigationController.setNavigationBarHidden(false, animated: false)
                    navigationController.setViewControllers(
                        [addShiftViewController],
                        animated: true
                    )
                }
                navigationController.pushViewController(reviewViewController, animated: true)
            }
            navigationController.pushViewController(payPeriodViewController, animated: true)
        }

        navigationController.setViewControllers([startViewController], animated: false)
        return navigationController
    }

    private func presentStartupError() {
        guard let presenter = window?.rootViewController else { return }

        let alert = UIAlertController(
            title: String(localized: "application.startupError.title", table: "Localizable"),
            message: String(localized: "application.startupError.message", table: "Localizable"),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: String(localized: "application.startupError.retry", table: "Localizable"),
                style: .default
            ) { [weak self] _ in
                self?.startStartup()
            }
        )
        presenter.present(alert, animated: true)
    }
}
