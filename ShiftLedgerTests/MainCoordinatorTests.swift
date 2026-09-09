import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct MainCoordinatorTests {
    @Test("Main flow installs one stable Overview root")
    func startsWithOneOverviewRoot() throws {
        let harness = try makeHarness()

        harness.coordinator.start()

        #expect(harness.navigationController.viewControllers.count == 1)
        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.isNavigationBarHidden == false)
    }

    @Test("Add Shift completion reloads and returns to the same Overview")
    func addShiftCompletionReturnsToSameOverview() throws {
        let harness = try makeHarness()
        harness.coordinator.start()

        harness.overview.onAddShift?()
        let addShift = try #require(
            harness.navigationController.topViewController as? AddShiftViewController
        )
        let callbackShift = try makeShift()
        addShift.onSaved?(callbackShift)

        #expect(harness.metrics.overviewLoadCount == 1)
        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.viewControllers.count == 1)
    }

    @Test("Actual Gross uses the comparison dependency and opens Result")
    func actualGrossPushesResultUsingPreparedComparison() throws {
        let harness = try makeHarness()
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        let actualGross = try ActualGross(amount: 75)
        entry.onContinue?(actualGross)

        #expect(harness.metrics.preparedPeriods == [period])
        #expect(harness.metrics.preparedActualGrosses == [actualGross])
        #expect(harness.navigationController.topViewController is PaycheckResultViewController)
    }

    @Test("Paycheck Result Done returns to the stable Overview root")
    func resultDoneReturnsToSameOverview() throws {
        let harness = try makeHarness()
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        entry.onContinue?(try ActualGross(amount: 75))
        let result = try #require(
            harness.navigationController.topViewController as? PaycheckResultViewController
        )
        result.onDone?()

        #expect(harness.navigationController.topViewController === harness.overview)
        #expect(harness.navigationController.viewControllers.count == 1)
    }

    @Test("Native Back pops child screens without route-history repair")
    func nativeBackUsesTheNavigationControllerStack() throws {
        let harness = try makeHarness()
        harness.coordinator.start()

        harness.overview.onAddShift?()
        #expect(harness.navigationController.topViewController is AddShiftViewController)
        _ = harness.navigationController.popViewController(animated: false)
        #expect(harness.navigationController.topViewController === harness.overview)

        let period = try harness.job.payCalculationPeriod(for: makeShift())
        harness.overview.onCheckPaycheck?(period)
        #expect(harness.navigationController.topViewController is ActualGrossEntryViewController)
        _ = harness.navigationController.popViewController(animated: false)
        #expect(harness.navigationController.topViewController === harness.overview)
    }

    @Test("Comparison failure remains on Actual Gross with a neutral localized alert")
    func comparisonFailureStaysOnEntry() throws {
        let harness = try makeHarness(prepareComparison: { _, _, _ in
            throw MainCoordinatorTestError.comparisonFailed
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = harness.navigationController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        harness.coordinator.start()
        let period = try harness.job.payCalculationPeriod(for: makeShift())

        harness.overview.onCheckPaycheck?(period)
        let entry = try #require(
            harness.navigationController.topViewController as? ActualGrossEntryViewController
        )
        entry.onContinue?(try ActualGross(amount: 75))

        let alert = try #require(entry.presentedViewController as? UIAlertController)
        #expect(harness.navigationController.topViewController === entry)
        #expect(alert.title == String(
            localized: "application.paycheckComparisonError.title",
            table: "Localizable"
        ))
        #expect(alert.message == String(
            localized: "application.paycheckComparisonError.message",
            table: "Localizable"
        ))
    }

    private func makeHarness(
        prepareComparison: @escaping @MainActor (Job, PayCalculationPeriod, ActualGross) throws -> PaycheckComparison = { job, period, actualGross in
            try job.paycheckComparison(for: period, actualGross: actualGross, from: [])
        }
    ) throws -> Harness {
        let job = try makeJob()
        let metrics = Metrics()
        let overview = OverviewViewController(
            viewModel: OverviewViewModel(
                job: job,
                loadShifts: {
                    metrics.overviewLoadCount += 1
                    return []
                },
                currentDate: { Date(timeIntervalSinceReferenceDate: 0) }
            ),
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier
        )
        let navigationController = NonAnimatingNavigationController()
        let dependencies = MainCoordinator.Dependencies(
            makeOverview: { _ in overview },
            makeAddShift: { job in
                AddShiftViewController(
                    viewModel: AddShiftViewModel(
                        timeZoneIdentifier: job.timeZoneIdentifier,
                        saveShift: { _ in .success(()) }
                    )
                )
            },
            makeActualGrossEntry: { currencyCode in
                ActualGrossEntryViewController(
                    viewModel: ActualGrossEntryViewModel(decimalInputLocale: Locale(identifier: "en_US")),
                    currencyCode: currencyCode
                )
            },
            preparePaycheckComparison: { job, period, actualGross in
                metrics.preparedPeriods.append(period)
                metrics.preparedActualGrosses.append(actualGross)
                return try prepareComparison(job, period, actualGross)
            },
            makePaycheckResult: { comparison, job in
                PaycheckResultAssembly.make(
                    comparison: comparison,
                    currencyCode: job.currencyCode,
                    timeZoneIdentifier: job.timeZoneIdentifier
                )
            }
        )
        let coordinator = MainCoordinator(
            navigationController: navigationController,
            job: job,
            dependencies: dependencies
        )

        return Harness(
            coordinator: coordinator,
            navigationController: navigationController,
            overview: overview,
            job: job,
            metrics: metrics
        )
    }

    private func makeJob() throws -> Job {
        try Job(
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .scheduled(.calendarMonthly),
            payRates: [try PayRate(amount: 100, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeShift() throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        return try Shift(start: start, end: start.addingTimeInterval(3_600))
    }
}

@MainActor
private final class Harness {
    let coordinator: MainCoordinator
    let navigationController: UINavigationController
    let overview: OverviewViewController
    let job: Job
    let metrics: Metrics

    init(
        coordinator: MainCoordinator,
        navigationController: UINavigationController,
        overview: OverviewViewController,
        job: Job,
        metrics: Metrics
    ) {
        self.coordinator = coordinator
        self.navigationController = navigationController
        self.overview = overview
        self.job = job
        self.metrics = metrics
    }
}

@MainActor
private final class Metrics {
    var overviewLoadCount = 0
    var preparedPeriods: [PayCalculationPeriod] = []
    var preparedActualGrosses: [ActualGross] = []
}

private enum MainCoordinatorTestError: Error {
    case comparisonFailed
}

private final class NonAnimatingNavigationController: UINavigationController {
    override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        super.pushViewController(viewController, animated: false)
    }

    override func popToViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) -> [UIViewController]? {
        super.popToViewController(viewController, animated: false)
    }
}
