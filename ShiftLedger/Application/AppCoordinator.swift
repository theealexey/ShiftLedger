import Foundation
import UIKit

@MainActor
final class AppCoordinator {
    private enum ActiveFlow {
        case onboarding(OnboardingCoordinator)
        case main(MainCoordinator)
    }

    private let window: UIWindow
    private let resolveLaunch: @MainActor () async throws -> AppLaunchResolution
    private let makeNavigationController: @MainActor () -> UINavigationController
    private var initialFlowResolutionTask: Task<Void, Never>?
    private var activeFlow: ActiveFlow?

    init(window: UIWindow) {
        self.window = window
        resolveLaunch = {
            try await AppLaunchResolver().resolve()
        }
        makeNavigationController = {
            UINavigationController()
        }
    }

    init(
        window: UIWindow,
        resolveLaunch: @escaping @MainActor () async throws -> AppLaunchResolution,
        makeNavigationController: @escaping @MainActor () -> UINavigationController = {
            UINavigationController()
        }
    ) {
        self.window = window
        self.resolveLaunch = resolveLaunch
        self.makeNavigationController = makeNavigationController
    }

    func start() {
        guard activeFlow == nil else {
            return
        }

        startInitialFlowResolution()
    }

    func stop() {
        cancelInitialFlowResolution()
    }

    @discardableResult
    private func startInitialFlowResolution() -> Task<Void, Never> {
        cancelInitialFlowResolution()

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let resolution = try await resolveLaunch()

                try Task.checkCancellation()

                if let job = resolution.job {
                    installMainFlow(
                        job: job,
                        composition: resolution.composition
                    )
                } else {
                    installOnboardingFlow(
                        composition: resolution.composition
                    )
                }

            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                installStartupFailureState()
            }
        }

        initialFlowResolutionTask = task
        return task
    }

    private func cancelInitialFlowResolution() {
        initialFlowResolutionTask?.cancel()
        initialFlowResolutionTask = nil
    }

    private func installOnboardingFlow(composition: AppFlowComposition) {
        let navigationController = makeNavigationController()
        let coordinator = OnboardingCoordinator(
            navigationController: navigationController,
            dependencies: composition.makeOnboardingDependencies(),
            onFinished: { [weak self] job in
                self?.installMainFlow(job: job, composition: composition)
            }
        )

        coordinator.start()
        activeFlow = .onboarding(coordinator)
        installRoot(navigationController)
    }

    private func installMainFlow(job: Job, composition: AppFlowComposition) {
        let navigationController = makeNavigationController()
        let coordinator = MainCoordinator(
            navigationController: navigationController,
            job: job,
            dependencies: composition.makeMainDependencies()
        )

        coordinator.start()
        activeFlow = .main(coordinator)
        installRoot(navigationController)
    }

    private func installStartupFailureState() {
        let failureViewController = StartupFailureViewController { [weak self] in
            self?.start()
        }

        installRoot(failureViewController)
        failureViewController.presentRetryAlert()
    }

    private func installRoot(_ rootViewController: UIViewController) {
        window.rootViewController = rootViewController

        if window.isHidden {
            window.makeKeyAndVisible()
        }
    }
}

@MainActor
private final class StartupFailureViewController: UIViewController {
    private let onRetry: () -> Void

    init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func presentRetryAlert() {
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
                self?.onRetry()
            }
        )
        present(alert, animated: true)
    }
}
