import Foundation
import UIKit

@MainActor
final class MainCoordinator {
    struct Dependencies {
        let makeOverview: @MainActor (Job) -> OverviewViewController
        let makeAddShift: @MainActor (Job) -> AddShiftViewController
        let makeAddWorkType: @MainActor (Job) -> AddWorkTypeViewController
        let makeEditShift: @MainActor (Job, Shift) -> EditShiftViewController
        let makeActualGrossEntry: @MainActor (String) -> ActualGrossEntryViewController
        let preparePaycheckComparison: @MainActor (Job, PayCalculationPeriod, ActualGross) throws -> PaycheckComparison
        let makePaycheckResult: @MainActor (PaycheckComparison, Job) -> PaycheckResultViewController
    }

    private enum Route {
        case overview
        case addShift
        case addWorkType
        case editShift(Shift)
        case actualGrossEntry(PayCalculationPeriod)
        case paycheckResult(PaycheckComparison)
    }

    private let navigationController: UINavigationController
    private var job: Job
    private let dependencies: Dependencies
    private let overviewViewController: OverviewViewController

    init(
        navigationController: UINavigationController,
        job: Job,
        dependencies: Dependencies
    ) {
        self.navigationController = navigationController
        self.job = job
        self.dependencies = dependencies
        overviewViewController = dependencies.makeOverview(job)

        configureOverviewCallbacks()
    }

    func start() {
        navigationController.setNavigationBarHidden(false, animated: false)
        navigate(to: .overview)
    }

    private func configureOverviewCallbacks() {
        overviewViewController.onAddShift = { [weak self] in
            self?.navigate(to: .addShift)
        }
        overviewViewController.onAddWorkType = { [weak self] in
            self?.navigate(to: .addWorkType)
        }
        overviewViewController.onEditShift = { [weak self] shift in
            self?.navigate(to: .editShift(shift))
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
        case .addWorkType:
            showAddWorkType()
        case let .editShift(shift):
            showEditShift(shift)
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

    private func completeAddShift(selectingShiftID: UUID) {
        overviewViewController.reload(selectingShiftID: selectingShiftID)
        navigationController.popToViewController(overviewViewController, animated: true)
    }

    private func showAddWorkType() {
        let viewController = dependencies.makeAddWorkType(job)
        viewController.onSaved = { [weak self] updatedJob in
            self?.completeAddWorkType(with: updatedJob)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func completeAddWorkType(with updatedJob: Job) {
        job = updatedJob
        overviewViewController.reload(job: updatedJob)
        navigationController.popToViewController(overviewViewController, animated: true)
    }

    private func showEditShift(_ shift: Shift) {
        let viewController = dependencies.makeEditShift(job, shift)
        viewController.onSaved = { [weak self] updatedShift in
            self?.completeEditShift(updatedShift)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func completeEditShift(_ shift: Shift) {
        overviewViewController.reload(selectingShiftID: shift.id)
        navigationController.popToViewController(overviewViewController, animated: true)
    }

    private func showActualGrossEntry(for period: PayCalculationPeriod) {
        let viewController = dependencies.makeActualGrossEntry(job.currencyCode)
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
