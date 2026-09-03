import CoreData
import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct AppCoordinatorTests {
    @Test("Startup failure presents a localized retry alert")
    func startupFailurePresentsLocalizedError() async throws {
        var loaderCallCount = 0
        let loader: @MainActor () async throws -> CoreDataStack = {
            loaderCallCount += 1
            throw AppCoordinatorTestError.loadFailed
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(window: window, loadCoreDataStack: loader)
        defer { tearDown(window, coordinator: coordinator) }

        let task = coordinator.startStartup()
        await task.value

        #expect(loaderCallCount == 1)
        let loadingViewController = try #require(window.rootViewController)
        let alert = try #require(
            loadingViewController.presentedViewController as? UIAlertController
        )
        #expect(alert.title == String(
            localized: "application.startupError.title",
            table: "Localizable"
        ))
        #expect(alert.message == String(
            localized: "application.startupError.message",
            table: "Localizable"
        ))
        #expect(alert.actions.count == 1)
        #expect(alert.actions.first?.title == String(
            localized: "application.startupError.retry",
            table: "Localizable"
        ))
    }

    @Test("Retry reruns startup and installs onboarding")
    func failedStartupCanRetrySuccessfully() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        var loaderCallCount = 0
        let loader: @MainActor () async throws -> CoreDataStack = {
            loaderCallCount += 1
            if loaderCallCount == 1 {
                throw AppCoordinatorTestError.loadFailed
            }
            return stack
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(window: window, loadCoreDataStack: loader)
        defer { tearDown(window, coordinator: coordinator) }

        let firstTask = coordinator.startStartup()
        await firstTask.value
        #expect(loaderCallCount == 1)
        let failedRoot = try #require(window.rootViewController)
        #expect(failedRoot.presentedViewController is UIAlertController)

        let retryTask = coordinator.startStartup()
        await retryTask.value

        #expect(loaderCallCount == 2)
        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        #expect(navigationController.viewControllers.first is JobSetupViewController)
        #expect(navigationController.presentedViewController == nil)
    }

    @Test("Cancelling suspended startup leaves the loading root")
    func cancellingSuspendedStartupDoesNotInstallRootOrError() async throws {
        var enteredContinuation: CheckedContinuation<Void, Never>?
        var cancellationObserved = false
        let loader: @MainActor () async throws -> CoreDataStack = {
            enteredContinuation?.resume()
            enteredContinuation = nil

            do {
                try await Task.sleep(for: .seconds(60))
                throw AppCoordinatorTestError.unexpectedLoaderReturn
            } catch is CancellationError {
                cancellationObserved = true
                throw CancellationError()
            }
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(window: window, loadCoreDataStack: loader)
        defer { tearDown(window, coordinator: coordinator) }

        let task = coordinator.startStartup()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            enteredContinuation = continuation
        }
        let loadingViewController = try #require(window.rootViewController)

        coordinator.cancelStartup()
        await task.value

        #expect(cancellationObserved)
        #expect(window.rootViewController === loadingViewController)
        #expect(loadingViewController.presentedViewController == nil)
    }

    @Test("Persisted Job opens Add Shift")
    func existingJobInstallsAddShift() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }
        let job = try makeValidJob()
        try JobStorage(stack: stack).save(job)

        var loaderCallCount = 0
        let loader: @MainActor () async throws -> CoreDataStack = {
            loaderCallCount += 1
            return stack
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(window: window, loadCoreDataStack: loader)
        defer { tearDown(window, coordinator: coordinator) }

        let task = coordinator.startStartup()
        await task.value

        #expect(loaderCallCount == 1)
        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.viewControllers.first is AddShiftViewController)
    }

    @Test("Onboarding callbacks compose the production navigation flow")
    func onboardingNavigationFlow() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            loadCoreDataStack: { stack }
        )
        defer { tearDown(window, coordinator: coordinator) }

        let startupTask = coordinator.startStartup()
        await startupTask.value

        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        let startViewController = try #require(
            navigationController.viewControllers.first as? JobSetupViewController
        )
        let draft = makeValidDraft()

        startViewController.onContinue?(draft)
        let payPeriodViewController = try #require(
            navigationController.topViewController as? PayPeriodSetupViewController
        )

        payPeriodViewController.onBack?()
        #expect(navigationController.topViewController === startViewController)

        startViewController.onContinue?(draft)
        let secondPayPeriodViewController = try #require(
            navigationController.topViewController as? PayPeriodSetupViewController
        )
        secondPayPeriodViewController.onContinue?(draft)
        let reviewViewController = try #require(
            navigationController.topViewController as? JobSetupReviewViewController
        )

        reviewViewController.onBack?()
        #expect(navigationController.topViewController === secondPayPeriodViewController)

        secondPayPeriodViewController.onContinue?(draft)
        let secondReviewViewController = try #require(
            navigationController.topViewController as? JobSetupReviewViewController
        )
        secondReviewViewController.onFinished?(try makeValidJob())

        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.viewControllers.first is AddShiftViewController)
        #expect(navigationController.navigationBar.isHidden == false)
    }

    private func makeWindow() -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    private func tearDown(_ window: UIWindow, coordinator: AppCoordinator) {
        coordinator.cancelStartup()
        window.isHidden = true
        window.rootViewController = nil
    }

    private func makeTemporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftLedgerStartupTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("ShiftLedger.sqlite")
    }

    private func makeValidDraft() -> JobSetupDraft {
        JobSetupDraft(
            basePayAmountText: "100",
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycleKind: .perShift,
            payPeriodAnchorDate: nil
        )
    }

    private func makeValidJob() throws -> Job {
        try Job(
            id: try #require(UUID(uuidString: "A0000000-0000-0000-0000-000000000001")),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [try PayRate(amount: 100, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
    }

    private func removeTemporaryStoreDirectory(for storeURL: URL, stack: CoreDataStack) {
        let context = stack.viewContext
        context.reset()
        if let coordinator = context.persistentStoreCoordinator {
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }
}

private enum AppCoordinatorTestError: Error {
    case loadFailed
    case unexpectedLoaderReturn
}
