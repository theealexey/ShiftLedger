import Foundation
import UIKit
import Testing
@testable import ShiftLedger

@MainActor
struct JobSetupReviewViewControllerTests {
    @Test("Успешное сохранение вызывает completion один раз")
    func successfulSaveCompletesOnce() throws {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"
        draft.payCalculationCycleKind = .perShift
        var savedJobs: [Job] = []
        var completions = 0
        let viewController = JobSetupReviewViewController(
            viewModel: JobSetupReviewViewModel(draft: draft),
            saveJob: { savedJobs.append($0) }
        )
        viewController.onFinished = { completions += 1 }
        viewController.loadViewIfNeeded()

        viewController.start()
        viewController.start()

        #expect(savedJobs.count == 1)
        #expect(completions == 1)
    }

    @Test("Ошибка сохранения позволяет повторить попытку")
    func failedSaveCanRetry() throws {
        var draft = makeDraft()
        draft.basePayBasis = .fixedPerShift
        draft.basePayAmountText = "4000"
        draft.payCalculationCycleKind = .perShift
        var attempts = 0
        var completions = 0
        let viewController = JobSetupReviewViewController(
            viewModel: JobSetupReviewViewModel(draft: draft),
            saveJob: { _ in
                attempts += 1
                if attempts == 1 {
                    throw JobStorageError.jobAlreadyExists
                }
            }
        )
        viewController.onFinished = { completions += 1 }
        viewController.loadViewIfNeeded()

        viewController.start()
        viewController.start()

        #expect(attempts == 2)
        #expect(completions == 1)
    }

    private func makeDraft() -> JobSetupDraft {
        JobSetupDraft(
            name: "",
            basePayAmountText: "",
            currencyCode: "RUB",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: nil,
            payCalculationCycleKind: nil,
            payPeriodAnchorDate: nil
        )
    }
}
