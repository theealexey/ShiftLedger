import CoreData
import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct AppCoordinatorTests {
    @Test("Startup failure presents a localized retry alert")
    func startupFailurePresentsLocalizedError() async throws {
        var loaderCallCount = 0
        let resolveLaunch: @MainActor () async throws -> AppLaunchResolution = {
            loaderCallCount += 1
            throw AppCoordinatorTestError.loadFailed
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: resolveLaunch
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        try await waitUntil {
            loaderCallCount == 1
                && window.rootViewController?.presentedViewController is UIAlertController
        }

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
        let resolveLaunch: @MainActor () async throws -> AppLaunchResolution = {
            loaderCallCount += 1

            if loaderCallCount == 1 {
                throw AppCoordinatorTestError.loadFailed
            }

            return AppLaunchResolution(
                stack: stack,
                job: nil
            )
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: resolveLaunch
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        try await waitUntil {
            loaderCallCount == 1
                && window.rootViewController?.presentedViewController is UIAlertController
        }
        #expect(loaderCallCount == 1)
        let failedRoot = try #require(window.rootViewController)
        #expect(failedRoot.presentedViewController is UIAlertController)

        coordinator.start()
        try await waitUntil {
            loaderCallCount == 2
                && window.rootViewController is UINavigationController
        }

        #expect(loaderCallCount == 2)
        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        #expect(navigationController.viewControllers.first is JobSetupViewController)
        #expect(navigationController.presentedViewController == nil)
    }

    @Test("Cancelling suspended resolution does not install a stale root or error")
    func cancellingSuspendedResolutionDoesNotInstallRootOrError() async throws {
        var enteredContinuation: CheckedContinuation<Void, Never>?
        var cancellationObserved = false
        let resolveLaunch: @MainActor () async throws -> AppLaunchResolution = {
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
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: resolveLaunch
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            enteredContinuation = continuation
        }
        let existingRootViewController = try #require(window.rootViewController)

        coordinator.stop()
        try await waitUntil { cancellationObserved }

        #expect(cancellationObserved)
        #expect(window.rootViewController === existingRootViewController)
        #expect(existingRootViewController.presentedViewController == nil)
    }

    @Test("Repeated start replaces a pending initial resolution")
    func repeatedStartReplacesPendingResolution() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        var loadCallCount = 0
        var firstLoadStarted: CheckedContinuation<Void, Never>?
        var secondLoadStarted: CheckedContinuation<Void, Never>?
        let resolveLaunch: @MainActor () async throws -> AppLaunchResolution = {
            loadCallCount += 1

            if loadCallCount == 1 {
                firstLoadStarted?.resume()

                try await Task.sleep(for: .seconds(60))
                throw AppCoordinatorTestError.unexpectedLoaderReturn
            }

            secondLoadStarted?.resume()

            return AppLaunchResolution(
                stack: stack,
                job: nil
            )
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: resolveLaunch
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        await withCheckedContinuation { continuation in
            firstLoadStarted = continuation
        }

        coordinator.start()
        await withCheckedContinuation { continuation in
            secondLoadStarted = continuation
        }
        try await waitUntil { window.rootViewController is UINavigationController }

        #expect(loadCallCount == 2)
        #expect(window.rootViewController is UINavigationController)
    }

    @Test("Repeated start preserves an active flow")
    func repeatedStartWithActiveFlowIsANoOp() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        var loadCallCount = 0
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: {
                loadCallCount += 1

                return AppLaunchResolution(
                    stack: stack,
                    job: nil
                )
            }
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        try await waitUntil { window.rootViewController is UINavigationController }
        let initialRoot = try #require(window.rootViewController)
        coordinator.start()
        await Task.yield()

        #expect(loadCallCount == 1)
        #expect(window.rootViewController === initialRoot)
    }

    @Test("Persisted Job opens Overview as the only root")
    func existingJobInstallsOverview() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }
        let job = try makeValidJob()
        try JobStorage(stack: stack).save(job)

        var loaderCallCount = 0
        let resolveLaunch: @MainActor () async throws -> AppLaunchResolution = {
            loaderCallCount += 1

            return AppLaunchResolution(
                stack: stack,
                job: job
            )
        }
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: resolveLaunch
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        try await waitUntil { window.rootViewController is UINavigationController }

        #expect(loaderCallCount == 1)
        let navigationController = try #require(
            window.rootViewController as? UINavigationController
        )
        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.viewControllers.first is OverviewViewController)
        #expect(navigationController.viewControllers.first is AddShiftViewController == false)
        #expect(navigationController.isNavigationBarHidden == false)
    }

    @Test("Onboarding completion replaces its root with a new Main flow")
    func onboardingNavigationFlow() async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }

        let window = makeWindow(isKeyAndVisible: false)
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: {
                AppLaunchResolution(
                    stack: stack,
                    job: nil
                )
            },
            makeNavigationController: {
                NonAnimatingNavigationController()
            }
        )
        defer { tearDown(window, coordinator: coordinator) }

        coordinator.start()
        try await waitUntil { window.rootViewController is NonAnimatingNavigationController }

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

        let mainNavigationController = try #require(
            window.rootViewController as? NonAnimatingNavigationController
        )
        #expect(mainNavigationController !== navigationController)
        #expect(mainNavigationController.viewControllers.count == 1)
        #expect(mainNavigationController.viewControllers.first is OverviewViewController)
        #expect(mainNavigationController.navigationBar.isHidden == false)
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

    @Test("Actual Add Shift Save persists, reloads, and returns to the same Overview")
    func actualAddShiftSavePersistsReloadsAndReturnsToSameOverview() async throws {
        let job = try makeValidJob()
        let expectedShift = try makeShift(day: 20)

        try await withOverview(job: job) { stack, navigation, overview in
            overview.onAddShift?()
            let addShift = try #require(navigation.topViewController as? AddShiftViewController)
            #expect(addShift.navigationController === navigation)
            addShift.loadViewIfNeeded()

            try await selectDate(
                expectedShift.start,
                in: addShift,
                rowWithAccessibilityLabel: AddShiftStrings.start
            )
            try await selectDate(
                expectedShift.end,
                in: addShift,
                rowWithAccessibilityLabel: AddShiftStrings.end
            )
            try tapBarButtonItem(addShift.navigationItem.rightBarButtonItem)

            let persistedShifts = try ShiftStorage(stack: stack).loadAll()
            #expect(persistedShifts.count == 1)
            let persistedShift = try #require(persistedShifts.first)
            #expect(persistedShift.start == expectedShift.start)
            #expect(persistedShift.end == expectedShift.end)
            #expect(persistedShift.unpaidBreak == nil)
            #expect(navigation.topViewController === overview)
            #expect(navigation.viewControllers.count == 1)

            let count: UILabel = try requireView("overview.shiftCount.value", in: overview.view)
            #expect(count.text == "1")
            let period: UILabel = try requireView("overview.period.label", in: overview.view)
            #expect(period.text == OverviewFormatting.perShiftPeriod(
                persistedShift,
                timeZoneIdentifier: job.timeZoneIdentifier,
                locale: CurrencySelectionItem.applicationDisplayLocale
            ))
            let card: UIView = try requireView(
                "overview.shift.\(persistedShift.id.uuidString)",
                in: overview.view
            )
            #expect(card.accessibilityTraits.contains(.selected))
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
        body: @MainActor (CoreDataStack, NonAnimatingNavigationController, OverviewViewController) async throws -> Void
    ) async throws {
        let storeURL = try makeTemporaryStoreURL()
        let stack = try await CoreDataStack.load(storeURL: storeURL)
        defer { removeTemporaryStoreDirectory(for: storeURL, stack: stack) }
        try JobStorage(stack: stack).save(job)
        let window = makeWindow()
        let coordinator = AppCoordinator(
            window: window,
            resolveLaunch: {
                AppLaunchResolution(
                    stack: stack,
                    job: job
                )
            },
            makeNavigationController: { NonAnimatingNavigationController() }
        )
        defer { tearDown(window, coordinator: coordinator) }
        coordinator.start()
        try await waitUntil { window.rootViewController is NonAnimatingNavigationController }
        let navigation = try #require(window.rootViewController as? NonAnimatingNavigationController)
        let overview = try #require(navigation.topViewController as? OverviewViewController)
        overview.loadViewIfNeeded()
        try await body(stack, navigation, overview)
    }

    private func selectDate(
        _ date: Date,
        in addShift: AddShiftViewController,
        rowWithAccessibilityLabel accessibilityLabel: String
    ) async throws {
        let row = try requireControl(
            accessibilityLabel: accessibilityLabel,
            in: addShift.view
        )
        row.sendActions(for: .touchUpInside)

        let pickerNavigationController = try #require(
            addShift.presentedViewController as? UINavigationController
        )
        let pickerViewController = try #require(
            pickerNavigationController.topViewController as? ShiftDateTimePickerViewController
        )
        pickerViewController.loadViewIfNeeded()
        let picker: UIDatePicker = try requireFirstDescendant(of: UIDatePicker.self, in: pickerViewController.view)
        picker.date = date
        try tapBarButtonItem(pickerViewController.navigationItem.rightBarButtonItem)
        try await waitUntil { addShift.presentedViewController == nil }
    }

    private func tapBarButtonItem(_ item: UIBarButtonItem?) throws {
        let item = try #require(item)
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action)
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

    private func requireControl(accessibilityLabel: String, in root: UIView) throws -> UIControl {
        func find(in view: UIView) -> UIControl? {
            if let control = view as? UIControl,
               control.accessibilityLabel == accessibilityLabel {
                return control
            }
            for child in view.subviews {
                if let found = find(in: child) {
                    return found
                }
            }
            return nil
        }

        return try #require(find(in: root))
    }

    private func requireFirstDescendant<View: UIView>(
        of type: View.Type,
        in root: UIView
    ) throws -> View {
        func find(in view: UIView) -> View? {
            if let match = view as? View {
                return match
            }
            for child in view.subviews {
                if let found = find(in: child) {
                    return found
                }
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
            workTypeID: testWorkTypeID,
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
        coordinator.stop()
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

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<100 {
            if condition() {
                return
            }

            await Task.yield()
        }

        throw AppCoordinatorTestError.timedOut
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
            id: testWorkTypeID,
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
    case timedOut
}
