import Foundation
import UIKit

@MainActor
final class OnboardingCoordinator {
    struct Dependencies {
        let makeJobSetup: @MainActor () -> JobSetupViewController
        let makePayPeriod: @MainActor (JobSetupDraft) -> PayPeriodSetupViewController
        let makeReview: @MainActor (JobSetupDraft) -> JobSetupReviewViewController
    }

    private enum Route {
        case jobSetup
        case payPeriod(JobSetupDraft)
        case review(JobSetupDraft)
    }

    private let navigationController: UINavigationController
    private let dependencies: Dependencies
    private let onFinished: (Job) -> Void

    init(
        navigationController: UINavigationController,
        dependencies: Dependencies,
        onFinished: @escaping (Job) -> Void
    ) {
        self.navigationController = navigationController
        self.dependencies = dependencies
        self.onFinished = onFinished
    }

    func start() {
        navigationController.setNavigationBarHidden(true, animated: false)
        navigate(to: .jobSetup)
    }

    private func navigate(to route: Route) {
        switch route {
        case .jobSetup:
            showJobSetup()
        case let .payPeriod(draft):
            showPayPeriod(for: draft)
        case let .review(draft):
            showReview(for: draft)
        }
    }

    private func showJobSetup() {
        let viewController = dependencies.makeJobSetup()
        viewController.onContinue = { [weak self] draft in
            self?.navigate(to: .payPeriod(draft))
        }
        navigationController.setViewControllers([viewController], animated: false)
    }

    private func showPayPeriod(for draft: JobSetupDraft) {
        let viewController = dependencies.makePayPeriod(draft)
        viewController.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewController.onContinue = { [weak self] nextDraft in
            self?.navigate(to: .review(nextDraft))
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showReview(for draft: JobSetupDraft) {
        let viewController = dependencies.makeReview(draft)
        viewController.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewController.onFinished = { [weak self] job in
            self?.completeOnboarding(with: job)
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func completeOnboarding(with job: Job) {
        onFinished(job)
    }
}
