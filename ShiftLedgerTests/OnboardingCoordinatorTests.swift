import Testing
import UIKit
@testable import ShiftLedger

@MainActor
struct OnboardingCoordinatorTests {
    @Test("Onboarding starts at Job Setup and navigates through Pay Period")
    func startsAndNavigatesToPayPeriod() {
        let navigationController = UINavigationController()
        let start = makeJobSetup()
        let payPeriod = makePayPeriod()
        let review = makeReview(saveJob: { _ in .failure(.persistence) })
        let coordinator = makeCoordinator(
            navigationController: navigationController,
            start: start,
            payPeriod: payPeriod,
            review: review
        )

        coordinator.start()

        #expect(navigationController.isNavigationBarHidden)
        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.topViewController === start)

        start.onContinue?(makeDraft())

        #expect(navigationController.topViewController === payPeriod)
        #expect(navigationController.viewControllers.count == 2)
    }

    @Test("Onboarding back actions use the UIKit navigation stack")
    func backActionsPopToExistingScreens() {
        let navigationController = UINavigationController()
        let start = makeJobSetup()
        let payPeriod = makePayPeriod()
        let review = makeReview(saveJob: { _ in .failure(.persistence) })
        let coordinator = makeCoordinator(
            navigationController: navigationController,
            start: start,
            payPeriod: payPeriod,
            review: review
        )
        coordinator.start()

        start.onContinue?(makeDraft())
        payPeriod.onBack?()
        #expect(navigationController.topViewController === start)

        start.onContinue?(makeDraft())
        payPeriod.onContinue?(makeDraft())
        #expect(navigationController.topViewController === review)

        review.onBack?()
        #expect(navigationController.topViewController === payPeriod)
    }

    @Test("Successful Review save reports the persisted Job exactly once")
    func successfulSaveCompletesOnboardingOnce() {
        let navigationController = UINavigationController()
        let start = makeJobSetup()
        let payPeriod = makePayPeriod()
        let review = makeReview(saveJob: { _ in .success(()) })
        var finishedJobs: [Job] = []
        let coordinator = makeCoordinator(
            navigationController: navigationController,
            start: start,
            payPeriod: payPeriod,
            review: review,
            onFinished: { finishedJobs.append($0) }
        )
        coordinator.start()

        start.onContinue?(makeDraft())
        payPeriod.onContinue?(makeDraft())
        review.start()
        review.start()

        #expect(finishedJobs.count == 1)
        #expect(finishedJobs.first != nil)
    }

    private func makeCoordinator(
        navigationController: UINavigationController,
        start: JobSetupViewController,
        payPeriod: PayPeriodSetupViewController,
        review: JobSetupReviewViewController,
        onFinished: @escaping (Job) -> Void = { _ in }
    ) -> OnboardingCoordinator {
        OnboardingCoordinator(
            navigationController: navigationController,
            dependencies: .init(
                makeJobSetup: { start },
                makePayPeriod: { _ in payPeriod },
                makeReview: { _ in review }
            ),
            onFinished: onFinished
        )
    }

    private func makeJobSetup() -> JobSetupViewController {
        JobSetupViewController(
            viewModel: JobSetupViewModel(
                initialCurrencyCode: "USD",
                initialTimeZoneIdentifier: "Europe/Stockholm"
            )
        )
    }

    private func makePayPeriod() -> PayPeriodSetupViewController {
        PayPeriodSetupViewController(viewModel: PayPeriodSetupViewModel(draft: makeDraft()))
    }

    private func makeReview(
        saveJob: @escaping (Job) -> Result<Void, JobSetupReviewSaveFailure>
    ) -> JobSetupReviewViewController {
        JobSetupReviewViewController(
            viewModel: JobSetupReviewViewModel(
                draft: makeDraft(),
                saveJob: saveJob
            )
        )
    }

    private func makeDraft() -> JobSetupDraft {
        JobSetupDraft(
            basePayAmountText: "100",
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycleKind: .perShift,
            payPeriodAnchorDate: nil
        )
    }
}
