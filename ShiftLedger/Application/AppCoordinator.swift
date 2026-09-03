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
                    let addShiftViewController = AddShiftAssembly.make(
                        job: job,
                        stack: stack
                    )
                    let navigationController = makeNavigationController()
                    navigationController.setViewControllers(
                        [addShiftViewController],
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
                    stack: stack
                )
                reviewViewController.onBack = { [weak navigationController] in
                    navigationController?.popViewController(animated: true)
                }
                reviewViewController.onFinished = { [weak navigationController] job in
                    guard let navigationController else { return }

                    let addShiftViewController = AddShiftAssembly.make(
                        job: job,
                        stack: stack
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
