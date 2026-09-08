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

    @Test("Persisted Job opens Overview as the only root")
    func existingJobInstallsOverview() async throws {
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
        #expect(navigationController.viewControllers.first is OverviewViewController)
        #expect(navigationController.viewControllers.first is AddShiftViewController == false)
        #expect(navigationController.isNavigationBarHidden == false)
    }

    @Test("Onboarding callbacks compose the production navigation flow")
    func onboardingNavigationFlow() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        let window = makeWindow(isKeyAndVisible: false)
        let coordinator = AppCoordinator(
            window: window,
            loadCoreDataStack: { stack },
            makeNavigationController: {
                NonAnimatingNavigationController()
            }
        )
        defer { tearDown(window, coordinator: coordinator) }

        let startupTask = coordinator.startStartup()
        await startupTask.value

        let navigationController = try #require(
            window.rootViewController as? NonAnimatingNavigationController
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
        secondReviewViewController.start()

        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.viewControllers.first is OverviewViewController)
        #expect(navigationController.navigationBar.isHidden == false)
    }

    @Test("Add Shift saves return to the same Overview and reload persisted data")
    func addShiftReturnsAndReloads() async throws {
        try await withOverview(job: makeValidJob()) { stack, navigation, overview in
            let empty: UIView = try requireView("overview.empty.container", in: overview.view)
            #expect(empty.isHidden == false)
            overview.onAddShift?()
            let addShift = try #require(navigation.topViewController as? AddShiftViewController)
            #expect(addShift.navigationController === navigation)
            let persisted = try makeShift(day: 20)
            try ShiftStorage(stack: stack).save(persisted)

            // The callback value differs deliberately: only storage may supply the Overview data.
            addShift.onSaved?(try makeShift(day: 21))

            #expect(navigation.topViewController === overview)
            #expect(navigation.viewControllers.count == 1)
            let count: UILabel = try requireView("overview.shiftCount.value", in: overview.view)
            #expect(count.text == "1")
            #expect(empty.isHidden)
            let period: UILabel = try requireView("overview.period.label", in: overview.view)
            #expect(period.text == OverviewFormatting.perShiftPeriod(
                persisted,
                timeZoneIdentifier: "Europe/Stockholm",
                locale: CurrencySelectionItem.applicationDisplayLocale
            ))
        }
    }

    @Test("Check Paycheck uses supplied period, Job currency and persisted Domain comparison")
    func checkPaycheckUsesDomainOutput() async throws {
        let job = try makeValidJob()
        try await withOverview(job: job) { stack, navigation, overview in
            let shift = try makeShift(day: 20)
            try ShiftStorage(stack: stack).save(shift)
            let period = try job.payCalculationPeriod(for: shift)
            overview.onCheckPaycheck?(period)
            let entry = try #require(navigation.topViewController as? ActualGrossEntryViewController)
            entry.loadViewIfNeeded()
            let currency: UILabel = try requireView("actualGrossEntry.currency", in: entry.view)
            #expect(currency.text == job.currencyCode)
            let actual = try ActualGross(amount: 750)
            entry.onContinue?(actual)
            let result = try #require(navigation.topViewController as? PaycheckResultViewController)
            let comparison = try job.paycheckComparison(for: period, actualGross: actual, from: [shift])
            try expectSummary(result, comparison: comparison, job: job)
        }
    }

    @Test("Comparison loads shifts persisted after Overview rendered")
    func comparisonReadsFreshPersistence() async throws {
        let job = try makeValidJob(cycle: .scheduled(.calendarMonthly))
        try await withOverview(job: job) { stack, navigation, overview in
            let first = try makeShift(day: 20)
            let second = try makeShift(day: 21)
            let storage = ShiftStorage(stack: stack)
            try storage.save(first)
            overview.reload()
            let period = try job.payCalculationPeriod(for: first)
            try storage.save(second)
            overview.onCheckPaycheck?(period)
            let entry = try #require(navigation.topViewController as? ActualGrossEntryViewController)
            let actual = try ActualGross(amount: 1_500)
            entry.onContinue?(actual)
            let result = try #require(navigation.topViewController as? PaycheckResultViewController)
            let comparison = try job.paycheckComparison(for: period, actualGross: actual, from: [first, second])
            #expect(comparison.expected.expectedGross == 1_600)
            try expectSummary(result, comparison: comparison, job: job)
        }
    }

    @Test("Scheduled zero-shift comparison presents summary and empty breakdown")
    func scheduledZeroShiftFlow() async throws {
        let job = try makeValidJob(cycle: .scheduled(.calendarMonthly))
        try await withOverview(job: job) { _, navigation, overview in
            let period = try job.payCalculationPeriod(for: makeShift(day: 20))
            overview.onCheckPaycheck?(period)
            let entry = try #require(navigation.topViewController as? ActualGrossEntryViewController)
            let actual = try ActualGross(amount: 50)
            entry.onContinue?(actual)
            let result = try #require(navigation.topViewController as? PaycheckResultViewController)
            let comparison = try job.paycheckComparison(for: period, actualGross: actual, from: [])
            #expect(comparison.expected.expectedGross == .zero)
            #expect(comparison.expected.shiftBreakdowns.isEmpty)
            try expectSummary(result, comparison: comparison, job: job)
            let empty: UILabel = try requireView("paycheckResult.breakdown.empty", in: result.view)
            #expect(empty.isHidden == false)
            #expect(empty.text == PaycheckResultStrings.breakdownEmpty)
        }
    }

    @Test("Result Done returns to the original Overview without replacing it")
    func resultDoneReturnsToSameOverview() async throws {
        let job = try makeValidJob(cycle: .scheduled(.calendarMonthly))
        try await withOverview(job: job) { _, navigation, overview in
            let period = try job.payCalculationPeriod(for: makeShift(day: 20))
            overview.onCheckPaycheck?(period)
            let entry = try #require(navigation.topViewController as? ActualGrossEntryViewController)
            entry.onContinue?(try ActualGross(amount: .zero))
            let result = try #require(navigation.topViewController as? PaycheckResultViewController)
            result.onDone?()
            #expect(navigation.topViewController === overview)
            #expect(navigation.viewControllers.count == 1)
        }
    }

    @Test("Missing persisted Job produces one localized comparison alert and retains input")
    func comparisonFailureStaysOnEntry() async throws {
        let job = try makeValidJob()
        try await withOverview(job: job) { stack, navigation, overview in
            let period = try job.payCalculationPeriod(for: makeShift(day: 20))
            overview.onCheckPaycheck?(period)
            let entry = try #require(navigation.topViewController as? ActualGrossEntryViewController)
            entry.loadViewIfNeeded()
            let input: UITextField = try requireView("actualGrossEntry.amount.input", in: entry.view)
            input.text = "750"
            input.sendActions(for: .editingChanged)
            let jobs = try stack.viewContext.fetch(NSFetchRequest<JobEntity>(entityName: "JobEntity"))
            for entity in jobs { stack.viewContext.delete(entity) }
            try stack.viewContext.save()
            let actual = try ActualGross(amount: 750)
            entry.onContinue?(actual)
            let alert = try #require(entry.presentedViewController as? UIAlertController)
            entry.onContinue?(actual)
            #expect(entry.presentedViewController === alert)
            #expect(navigation.topViewController === entry)
            #expect(input.text == "750")
            #expect(alert.title == String(localized: "application.paycheckComparisonError.title", table: "Localizable"))
            #expect(alert.message == String(localized: "application.paycheckComparisonError.message", table: "Localizable"))
            #expect(alert.actions.count == 1)
            #expect(alert.actions.first?.title == String(localized: "common.cancel", table: "Localizable"))
        }
    }

    private func withOverview(
        job: Job,
        body: (CoreDataStack, NonAnimatingNavigationController, OverviewViewController) throws -> Void
    ) async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }
        try JobStorage(stack: stack).save(job)
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            loadCoreDataStack: { stack },
            makeNavigationController: { NonAnimatingNavigationController() }
        )
        defer { tearDown(window, coordinator: coordinator) }
        await coordinator.startStartup().value
        let navigation = try #require(window.rootViewController as? NonAnimatingNavigationController)
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.loadViewIfNeeded()
        try body(stack, navigation, overview)
    }

    private func expectSummary(
        _ result: PaycheckResultViewController,
        comparison: PaycheckComparison,
        job: Job
    ) throws {
        result.loadViewIfNeeded()
        let model = PaycheckResultFormatting.renderModel(
            comparison: comparison,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier,
            locale: CurrencySelectionItem.applicationDisplayLocale
        )
        for (identifier, text) in [
            ("paycheckResult.expected.value", model.expected),
            ("paycheckResult.actual.value", model.actual),
            ("paycheckResult.difference.value", model.difference)
        ] {
            let label: UILabel = try requireView(identifier, in: result.view)
            #expect(label.text == text)
        }
    }

    private func requireView<View: UIView>(_ identifier: String, in root: UIView) throws -> View {
        func find(in view: UIView) -> View? {
            if view.accessibilityIdentifier == identifier { return view as? View }
            for child in view.subviews {
                if let found = find(in: child) { return found }
            }
            return nil
        }
        return try #require(find(in: root))
    }

    private func makeShift(day: Int) throws -> Shift {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 8)))
        return try Shift(
            id: try #require(UUID(uuidString: String(format: "B0000000-0000-0000-0000-%012d", day))),
            start: start,
            end: start.addingTimeInterval(8 * 3_600)
        )
    }

    private func makeWindow(isKeyAndVisible: Bool = true) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        if isKeyAndVisible {
            window.makeKeyAndVisible()
        }
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

    private func makeValidJob(cycle: PayCalculationCycle = .perShift) throws -> Job {
        try Job(
            id: try #require(UUID(uuidString: "A0000000-0000-0000-0000-000000000001")),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: cycle,
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

private final class NonAnimatingNavigationController: UINavigationController {
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        super.popToViewController(viewController, animated: false)
    }

    override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        super.pushViewController(viewController, animated: false)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        super.popViewController(animated: false)
    }

    override func setViewControllers(
        _ viewControllers: [UIViewController],
        animated: Bool
    ) {
        super.setViewControllers(viewControllers, animated: false)
    }
}

private enum AppCoordinatorTestError: Error {
    case loadFailed
    case unexpectedLoaderReturn
}
