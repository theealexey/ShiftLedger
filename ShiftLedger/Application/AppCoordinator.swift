import Foundation
import UIKit

@MainActor
final class AppCoordinator {
    private enum ActiveFlow {
        case onboarding(OnboardingCoordinator)
        case main(MainCoordinator)
    }

    private let window: UIWindow
    private let loadCoreDataStack: @MainActor () async throws -> CoreDataStack
    private let makeNavigationController: @MainActor () -> UINavigationController
    private var initialFlowResolutionTask: Task<Void, Never>?
    private var activeFlow: ActiveFlow?

    init(window: UIWindow) {
        self.window = window
        loadCoreDataStack = {
            try await CoreDataStack.load()
        }
        makeNavigationController = {
            UINavigationController()
        }
    }

    init(
        window: UIWindow,
        loadCoreDataStack: @escaping @MainActor () async throws -> CoreDataStack,
        makeNavigationController: @escaping @MainActor () -> UINavigationController = {
            UINavigationController()
        }
    ) {
        self.window = window
        self.loadCoreDataStack = loadCoreDataStack
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
                try prepareLaunchStateForUITesting()

                let stack = try await loadCoreDataStack()
                try Task.checkCancellation()

                let job = try loadInitialJob(from: stack)

                if let job {
                    installMainFlow(job: job, stack: stack)
                } else {
                    installOnboardingFlow(stack: stack)
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

    private func prepareLaunchStateForUITesting() throws {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-store") {
            try CoreDataStack.resetPersistentStoreForUITesting()
        }
#endif
    }

    private func loadInitialJob(from stack: CoreDataStack) throws -> Job? {
        let jobStorage = JobStorage(stack: stack)

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-seed-job"),
           try jobStorage.load() == nil {
            let job = try Job(
                currencyCode: "SEK",
                timeZoneIdentifier: "Europe/Stockholm",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: [try PayRate(amount: 100, effectiveFrom: nil)],
                createdAt: Date(timeIntervalSinceReferenceDate: 0)
            )
            try jobStorage.save(job)
        }
#endif

        return try jobStorage.load()
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
