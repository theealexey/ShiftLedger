import Foundation
import UIKit

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private let loadCoreDataStack: @MainActor () async throws -> CoreDataStack
    private let makeNavigationController: @MainActor () -> UINavigationController
    private var startupTask: Task<Void, Never>?
    private var coreDataStack: CoreDataStack?

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
        startStartup()
    }

    func stop() {
        cancelStartup()
    }

    @discardableResult
    func startStartup() -> Task<Void, Never> {
        cancelStartup()

        let loadingViewController = makeLoadingViewController()
        window.rootViewController = loadingViewController

        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-store") {
                    try CoreDataStack.resetPersistentStoreForUITesting()
                }
#endif
                let stack = try await loadCoreDataStack()
                try Task.checkCancellation()

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
                let job = try jobStorage.load()

                try Task.checkCancellation()
                coreDataStack = stack

                if let job {
                    let navigationController = makeNavigationController()
                    let overview = makeOverviewViewController(
                        job: job,
                        stack: stack,
                        navigationController: navigationController
                    )
                    navigationController.setNavigationBarHidden(false, animated: false)
                    navigationController.setViewControllers(
                        [overview],
                        animated: false
                    )
                    try Task.checkCancellation()
                    window.rootViewController = navigationController
                } else {
                    let navigationController = makeOnboardingNavigationController(
                        stack: stack
                    )
                    navigationController.setNavigationBarHidden(true, animated: false)
                    try Task.checkCancellation()
                    window.rootViewController = navigationController
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }
                presentStartupError()
            }
        }

        startupTask = task
        return task
    }

    func cancelStartup() {
        startupTask?.cancel()
        startupTask = nil
        coreDataStack = nil
    }

    private func makeLoadingViewController() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        return viewController
    }

    private func makeOnboardingNavigationController(
        stack: CoreDataStack
    ) -> UINavigationController {
        let navigationController = makeNavigationController()
        let startViewController = JobSetupAssembly.makeStart(
            initialCurrencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "USD",
            initialTimeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )

        startViewController.onContinue = { [weak self, weak navigationController] draft in
            guard let navigationController else { return }

            let payPeriodViewController = JobSetupAssembly.makePayPeriod(draft: draft)
            payPeriodViewController.onBack = { [weak navigationController] in
                navigationController?.popViewController(animated: true)
            }
            payPeriodViewController.onContinue = { [weak self, weak navigationController] draft in
                guard let navigationController else { return }

                let reviewViewController = JobSetupAssembly.makeReview(
                    draft: draft,
                    stack: stack
                )
                reviewViewController.onBack = { [weak navigationController] in
                    navigationController?.popViewController(animated: true)
                }
                reviewViewController.onFinished = { [weak self, weak navigationController] job in
                    guard let self, let navigationController else { return }

                    let overview = makeOverviewViewController(
                        job: job,
                        stack: stack,
                        navigationController: navigationController
                    )
                    navigationController.setNavigationBarHidden(false, animated: false)
                    navigationController.setViewControllers(
                        [overview],
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

    private func makeOverviewViewController(
        job: Job,
        stack: CoreDataStack,
        navigationController: UINavigationController
    ) -> OverviewViewController {
        let overview = OverviewAssembly.make(job: job, stack: stack)
        overview.onAddShift = { [weak overview, weak navigationController] in
            guard let overview, let navigationController else { return }
            let addShift = AddShiftAssembly.make(job: job, stack: stack)
            addShift.onSaved = { [weak overview, weak navigationController] _ in
                guard let overview, let navigationController else { return }
                overview.reload()
                navigationController.popToViewController(overview, animated: true)
            }
            navigationController.pushViewController(addShift, animated: true)
        }
        overview.onCheckPaycheck = { [weak overview, weak navigationController] period in
            guard let overview, let navigationController else { return }
            let entry = ActualGrossEntryAssembly.make(currencyCode: job.currencyCode)
            entry.onContinue = { [weak entry, weak overview, weak navigationController] actualGross in
                guard let entry, let overview, let navigationController,
                      navigationController.topViewController === entry,
                      entry.presentedViewController == nil else { return }
                do {
                    let shifts = try ShiftStorage(stack: stack).loadAll()
                    let comparison = try job.paycheckComparison(
                        for: period,
                        actualGross: actualGross,
                        from: shifts
                    )
                    let result = PaycheckResultAssembly.make(
                        comparison: comparison,
                        currencyCode: job.currencyCode,
                        timeZoneIdentifier: job.timeZoneIdentifier
                    )
                    result.onDone = { [weak overview, weak navigationController] in
                        guard let overview else { return }
                        navigationController?.popToViewController(overview, animated: true)
                    }
                    navigationController.pushViewController(result, animated: true)
                } catch {
                    let alert = UIAlertController(
                        title: String(localized: "application.paycheckComparisonError.title", table: "Localizable"),
                        message: String(localized: "application.paycheckComparisonError.message", table: "Localizable"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(
                        title: String(localized: "common.cancel", table: "Localizable"),
                        style: .cancel
                    ))
                    entry.present(alert, animated: true)
                }
            }
            navigationController.pushViewController(entry, animated: true)
        }
        return overview
    }

    private func presentStartupError() {
        guard let presenter = window.rootViewController else { return }

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
