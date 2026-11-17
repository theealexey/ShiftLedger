import Foundation
import UIKit

@MainActor
final class MainCoordinator {
    struct Dependencies {
        let loadArchivedJobs: @MainActor () throws -> [JobSelectionItem]
        let makeArchivedJobHistory: @MainActor (UUID) throws -> ArchivedJobHistoryViewController
        let makeOverview: @MainActor (Job) -> OverviewViewController
        let makeAddShift: @MainActor (Job) -> AddShiftViewController
        let makeWorkTypes: @MainActor (Job) -> WorkTypesViewController
        let makeAddWorkType: @MainActor (Job) -> AddWorkTypeViewController
        let makeRenameWorkType: @MainActor (Job, WorkType) -> RenameWorkTypeViewController
        let makeChangePayRate: @MainActor (Job, WorkType) -> ChangePayRateViewController
        let makePayRateHistory: @MainActor (Job, WorkType) -> PayRateHistoryViewController
        let makeEditShift: @MainActor (Job, Shift) -> EditShiftViewController
        let makeActualGrossEntry: @MainActor (String) -> ActualGrossEntryViewController
        let preparePaycheckComparison: @MainActor (Job, PayCalculationPeriod, ActualGross) throws -> PaycheckComparison
        let makePaycheckResult: @MainActor (PaycheckComparison, Job) -> PaycheckResultViewController
    }

    private enum Route {
        case overview
        case addShift
        case workTypes
        case addWorkType(returningTo: WorkTypesViewController)
        case renameWorkType(WorkType, returningTo: WorkTypesViewController)
        case changePayRate(WorkType, returningTo: WorkTypesViewController)
        case payRateHistory(WorkType)
        case editShift(Shift, from: OverviewViewController)
        case actualGrossEntry(PayCalculationPeriod)
        case paycheckResult(PaycheckComparison)
    }

    private let appLock: AppLockController?
    private let navigationController: UINavigationController
    private let makeNavigationController: () -> UINavigationController
    let tabBarController = UITabBarController()
    private var job: Job
    private let dependencies: Dependencies
    private let overviewViewController: OverviewViewController
    private lazy var shiftsViewController = dependencies.makeOverview(job)
    private lazy var shiftsNavigation = makeNavigationController()
    private lazy var archiveNavigation = makeNavigationController()
    private lazy var settingsNavigation = makeNavigationController()

    init(
        navigationController: UINavigationController,
        job: Job,
        dependencies: Dependencies,
        appLock: AppLockController? = nil,
        makeNavigationController: @escaping () -> UINavigationController = { UINavigationController() }
    ) {
        self.navigationController = navigationController
        self.job = job
        self.dependencies = dependencies
        self.appLock = appLock
        self.makeNavigationController = makeNavigationController
        overviewViewController = dependencies.makeOverview(job)

        overviewViewController.usesHomeComposition = true
        configureOverviewCallbacks()
    }

    func start() {
        navigationController.setNavigationBarHidden(false, animated: false)
        guard tabBarController.viewControllers == nil else { return }
        navigate(to: .overview)
        shiftsViewController.showsShiftHistoryOnly = true
        shiftsViewController.onEditShift = { [weak self] shift in
            guard let self else { return }
            self.navigate(to: .editShift(shift, from: self.shiftsViewController))
        }
        shiftsNavigation.setViewControllers([shiftsViewController], animated: false)
        installArchivedJobs()
        installSettings()

        let tabs: [(UINavigationController, String, String, String)] = [
            (navigationController, String(localized: "tabs.home"), "house.fill", "home"),
            (shiftsNavigation, String(localized: "tabs.shifts"), "calendar", "shifts"),
            (archiveNavigation, String(localized: "tabs.archive"), "archivebox", "archive"),
            (settingsNavigation, String(localized: "settings.title"), "gearshape", "settings")
        ]
        for (stack, title, icon, id) in tabs {
            stack.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: icon), selectedImage: nil)
            stack.tabBarItem.accessibilityIdentifier = "tabs.\(id)"
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ShiftLedgerColors.surfacePrimary
        for items in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
                      appearance.compactInlineLayoutAppearance] {
            items.normal.iconColor = ShiftLedgerColors.textSecondary
            items.normal.titleTextAttributes = [.foregroundColor: ShiftLedgerColors.textSecondary]
            items.selected.iconColor = ShiftLedgerColors.accentPrimary
            items.selected.titleTextAttributes = [.foregroundColor: ShiftLedgerColors.accentPrimary]
        }
        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance
        tabBarController.tabBar.tintColor = ShiftLedgerColors.accentPrimary
        tabBarController.setViewControllers(tabs.map { $0.0 }, animated: false)
    }

    private func configureOverviewCallbacks() {
        overviewViewController.onShowSavedShifts = { [weak self] in
            guard let self else { return }
            self.tabBarController.selectedViewController = self.shiftsNavigation
        }
        overviewViewController.onAddShift = { [weak self] in
            self?.navigate(to: .addShift)
        }
        overviewViewController.onEditShift = { [weak self] shift in
            guard let self else { return }
            self.navigate(to: .editShift(shift, from: self.overviewViewController))
        }
        overviewViewController.onCheckPaycheck = { [weak self] period in
            self?.navigate(to: .actualGrossEntry(period))
        }
    }

    private func navigate(to route: Route) {
        switch route {
        case .overview:
            navigationController.setViewControllers([overviewViewController], animated: false)
        case .addShift:
            showAddShift()
        case .workTypes:
            showWorkTypes()
        case let .addWorkType(returningTo):
            showAddWorkType(returningTo: returningTo)
        case let .renameWorkType(workType, returningTo):
            showRenameWorkType(workType, returningTo: returningTo)
        case let .changePayRate(workType, returningTo):
            showChangePayRate(workType, returningTo: returningTo)
        case let .payRateHistory(workType):
            showPayRateHistory(workType)
        case let .editShift(shift, origin):
            showEditShift(shift, from: origin)
        case let .actualGrossEntry(period):
            showActualGrossEntry(for: period)
        case let .paycheckResult(comparison):
            showPaycheckResult(comparison)
        }
    }

    private func showAddShift() {
        let viewController = dependencies.makeAddShift(job)
        viewController.onSaved = { [weak self] shift in
            self?.completeAddShift(selectingShiftID: shift.id)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func installArchivedJobs() {
        let controller = ArchivedJobsViewController()
        controller.onReload = { [weak self, weak controller] in
            guard let self, let controller else { return }
            do {
                controller.reload(items: try self.dependencies.loadArchivedJobs())
            } catch {
                controller.showLoadFailure()
            }
        }
        controller.onSelectJob = { [weak self, weak controller] id in
            guard let self, let controller,
                  self.archiveNavigation.topViewController === controller else { return }
            do {
                let history = try self.dependencies.makeArchivedJobHistory(id)
                self.archiveNavigation.pushViewController(history, animated: true)
            } catch {
                controller.presentLoadError()
            }
        }
        controller.onReload?()
        archiveNavigation.setViewControllers([controller], animated: false)
    }

    private func completeAddShift(selectingShiftID: UUID) {
        overviewViewController.reload(selectingShiftID: selectingShiftID)
        reloadShifts()
        navigationController.popToViewController(overviewViewController, animated: true)
    }

    private func installSettings() {
        let activeWorkTypes = job.workTypes.filter { !$0.isArchived }
        let workType = activeWorkTypes.count == 1 ? activeWorkTypes.first : nil
        let controller = SettingsViewController(model: SettingsPresentation(
            currency: job.currencyCode,
            timeZone: job.timeZoneIdentifier,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            rateActionTitle: PayRateHistoryStrings.title,
            showsRates: workType != nil
        ), appLock: appLock)
        controller.onWillAppear = { [weak self, weak controller] in
            guard let self, let controller else { return }
            let active = self.job.workTypes.filter { !$0.isArchived }
            controller.updateRates(title: PayRateHistoryStrings.title, visible: active.count == 1)
        }
        controller.onManageWorkTypes = { [weak self] in self?.navigate(to: .workTypes) }
        controller.onRates = { [weak self] in
            guard let self else { return }
            let active = self.job.workTypes.filter { !$0.isArchived }
            guard active.count == 1, let current = active.first else { return }
            self.navigate(to: .payRateHistory(current))
        }
        settingsNavigation.setViewControllers([controller], animated: false)
    }

    private func refreshSettingsRates() {
        guard let settings = settingsNavigation.viewControllers.first as? SettingsViewController,
              settings.isViewLoaded else { return }
        let active = job.workTypes.filter { !$0.isArchived }
        settings.updateRates(title: PayRateHistoryStrings.title, visible: active.count == 1)
    }

    private func showWorkTypes() {
        let viewController = dependencies.makeWorkTypes(job)
        viewController.onArchived = { [weak self] updatedJob in
            self?.applyWorkTypeArchive(updatedJob)
        }
        viewController.onAddWorkType = { [weak self, weak viewController] in
            guard let viewController else { return }
            self?.navigate(to: .addWorkType(returningTo: viewController))
        }
        viewController.onRenameWorkType = { [weak self, weak viewController] workType in
            guard let viewController else { return }
            self?.navigate(to: .renameWorkType(workType, returningTo: viewController))
        }
        viewController.onChangePayRate = { [weak self, weak viewController] workType in
            guard let viewController else { return }
            self?.navigate(to: .changePayRate(workType, returningTo: viewController))
        }
        viewController.onPayRateHistory = { [weak self] workType in
            self?.navigate(to: .payRateHistory(workType))
        }
        settingsNavigation.pushViewController(viewController, animated: true)
    }

    private func applyWorkTypeArchive(_ updatedJob: Job) {
        job = updatedJob
        overviewViewController.reload(job: updatedJob)
        reloadShifts(job: updatedJob)
        refreshSettingsRates()
    }

    private func showAddWorkType(returningTo workTypesViewController: WorkTypesViewController) {
        let viewController = dependencies.makeAddWorkType(job)
        viewController.onSaved = { [weak self, weak workTypesViewController] updatedJob in
            guard let workTypesViewController else { return }
            self?.completeWorkTypeMutation(with: updatedJob, returningTo: workTypesViewController)
        }
        settingsNavigation.pushViewController(viewController, animated: true)
    }

    private func showRenameWorkType(
        _ workType: WorkType,
        returningTo workTypesViewController: WorkTypesViewController
    ) {
        let viewController = dependencies.makeRenameWorkType(job, workType)
        viewController.onSaved = { [weak self, weak workTypesViewController] updatedJob in
            guard let workTypesViewController else { return }
            self?.completeWorkTypeMutation(with: updatedJob, returningTo: workTypesViewController)
        }
        settingsNavigation.pushViewController(viewController, animated: true)
    }

    private func completeWorkTypeMutation(
        with updatedJob: Job,
        returningTo workTypesViewController: WorkTypesViewController
    ) {
        job = updatedJob
        overviewViewController.reload(job: updatedJob)
        reloadShifts(job: updatedJob)
        refreshSettingsRates()
        workTypesViewController.reload(workTypes: updatedJob.workTypes)
        settingsNavigation.popToViewController(workTypesViewController, animated: true)
    }

    private func showChangePayRate(
        _ workType: WorkType,
        returningTo workTypesViewController: WorkTypesViewController
    ) {
        let viewController = dependencies.makeChangePayRate(job, workType)
        viewController.onSaved = { [weak self, weak workTypesViewController] updatedJob in
            guard let workTypesViewController else { return }
            self?.completeWorkTypeMutation(with: updatedJob, returningTo: workTypesViewController)
        }
        settingsNavigation.pushViewController(viewController, animated: true)
    }

    private func showPayRateHistory(_ workType: WorkType) {
        let viewController = dependencies.makePayRateHistory(job, workType)
        settingsNavigation.pushViewController(viewController, animated: true)
    }

    private func showEditShift(_ shift: Shift, from origin: OverviewViewController) {
        let stack = origin === overviewViewController ? navigationController : shiftsNavigation
        let viewController = dependencies.makeEditShift(job, shift)
        viewController.onSaved = { [weak self, weak origin] updatedShift in
            guard let self, let origin else { return }
            self.completeShiftMutation(from: origin, selecting: updatedShift.id)
        }
        viewController.onDeleted = { [weak self, weak origin] _ in
            guard let self, let origin else { return }
            self.completeShiftMutation(from: origin, selecting: nil)
        }
        stack.pushViewController(viewController, animated: true)
    }

    private func completeShiftMutation(from origin: OverviewViewController, selecting id: UUID?) {
        let isHome = origin === overviewViewController
        if isHome {
            overviewViewController.reload(selectingShiftID: id)
            reloadShifts()
        } else {
            overviewViewController.reload()
            shiftsViewController.reload(selectingShiftID: id)
        }
        let stack = isHome ? navigationController : shiftsNavigation
        stack.popToViewController(origin, animated: true)
    }

    private func reloadShifts(job: Job? = nil) {
        if let job {
            shiftsViewController.reload(job: job)
        } else if shiftsViewController.isViewLoaded {
            shiftsViewController.reload()
        }
    }

    private func showActualGrossEntry(for period: PayCalculationPeriod) {
        let viewController = dependencies.makeActualGrossEntry(job.currencyCode)
        if let heading = overviewViewController.paycheckPeriodHeading(for: period) {
            viewController.displayPeriod(heading)
        }
        viewController.onContinue = { [weak self, weak viewController] actualGross in
            guard let self, let viewController else {
                return
            }

            self.continueFromActualGross(
                actualGross,
                for: period,
                entryViewController: viewController
            )
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func continueFromActualGross(
        _ actualGross: ActualGross,
        for period: PayCalculationPeriod,
        entryViewController: ActualGrossEntryViewController
    ) {
        guard navigationController.topViewController === entryViewController,
              entryViewController.presentedViewController == nil
        else {
            return
        }

        do {
            let comparison = try dependencies.preparePaycheckComparison(job, period, actualGross)
            navigate(to: .paycheckResult(comparison))
        } catch {
            presentComparisonError(from: entryViewController)
        }
    }

    private func showPaycheckResult(_ comparison: PaycheckComparison) {
        let viewController = dependencies.makePaycheckResult(comparison, job)
        if let heading = overviewViewController.paycheckPeriodHeading(for: comparison.expected.period) {
            viewController.displayPeriod(heading)
        }
        viewController.onDone = { [weak self] in
            self?.returnToOverview()
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func returnToOverview() {
        navigationController.popToViewController(overviewViewController, animated: true)
    }

    private func presentComparisonError(from viewController: ActualGrossEntryViewController) {
        let alert = UIAlertController(
            title: String(localized: "application.paycheckComparisonError.title", table: "Localizable"),
            message: String(localized: "application.paycheckComparisonError.message", table: "Localizable"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: String(localized: "common.cancel", table: "Localizable"),
            style: .cancel
        ))
        viewController.present(alert, animated: true)
    }
}
