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
                        stack: resolution.stack
                    )
                } else {
                    installOnboardingFlow(
                        stack: resolution.stack
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

    private func installOnboardingFlow(stack: CoreDataStack) {
        let navigationController = makeNavigationController()
        let coordinator = OnboardingCoordinator(
            navigationController: navigationController,
            dependencies: makeOnboardingDependencies(stack: stack),
            onFinished: { [weak self] job in
                self?.installMainFlow(job: job, stack: stack)
            }
        )

        coordinator.start()
        activeFlow = .onboarding(coordinator)
        installRoot(navigationController)
    }

    private func installMainFlow(job: Job, stack: CoreDataStack) {
        let navigationController = makeNavigationController()
        let coordinator = MainCoordinator(
            navigationController: navigationController,
            job: job,
            dependencies: makeMainDependencies(stack: stack)
        )

        coordinator.start()
        activeFlow = .main(coordinator)
        installRoot(navigationController)
    }

    private func makeOnboardingDependencies(
        stack: CoreDataStack
    ) -> OnboardingCoordinator.Dependencies {
        OnboardingCoordinator.Dependencies(
            makeJobSetup: {
                JobSetupAssembly.makeStart(
                    initialCurrencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "USD",
                    initialTimeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
                )
            },
            makePayPeriod: { draft in
                JobSetupAssembly.makePayPeriod(draft: draft)
            },
            makeReview: { draft in
                JobSetupAssembly.makeReview(draft: draft, stack: stack)
            }
        )
    }

    private func makeMainDependencies(
        stack: CoreDataStack
    ) -> MainCoordinator.Dependencies {
        MainCoordinator.Dependencies(
            makeOverview: { job in
                OverviewAssembly.make(job: job, stack: stack)
            },
            makeAddShift: { job in
                AddShiftAssembly.make(job: job, stack: stack)
            },
            makeAddWorkType: { job in
                AddWorkTypeAssembly.make(job: job, stack: stack)
            },
            makeEditShift: { job, shift in
                EditShiftAssembly.make(job: job, shift: shift, stack: stack)
            },
            makeActualGrossEntry: { currencyCode in
                ActualGrossEntryAssembly.make(currencyCode: currencyCode)
            },
            preparePaycheckComparison: { job, period, actualGross in
                let shifts = try ShiftStorage(stack: stack).loadAll()
                return try job.paycheckComparison(
                    for: period,
                    actualGross: actualGross,
                    from: shifts
                )
            },
            makePaycheckResult: { comparison, job in
                PaycheckResultAssembly.make(
                    comparison: comparison,
                    currencyCode: job.currencyCode,
                    timeZoneIdentifier: job.timeZoneIdentifier
                )
            }
        )
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
