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
        var completedJobs: [Job] = []
        let viewController = JobSetupReviewViewController(
            viewModel: JobSetupReviewViewModel(draft: draft),
            saveJob: { savedJobs.append($0) }
        )
        viewController.onFinished = { completedJobs.append($0) }
        viewController.loadViewIfNeeded()

        viewController.start()
        viewController.start()

        #expect(savedJobs.count == 1)
        #expect(completedJobs.count == 1)
        #expect(completedJobs.first == savedJobs.first)
    }

    @Test("Ошибка сохранения позволяет повторить попытку")
    func failedSaveCanRetry() throws {
        var draft = makeDraft()
        draft.basePayBasis = .fixedPerShift
        draft.basePayAmountText = "4000"
        draft.payCalculationCycleKind = .perShift
        var attempts = 0
        var savedJobs: [Job] = []
        let viewController = JobSetupReviewViewController(
            viewModel: JobSetupReviewViewModel(draft: draft),
            saveJob: { job in
                attempts += 1
                if attempts == 1 {
                    throw JobStorageError.jobAlreadyExists
                }
                savedJobs.append(job)
            }
        )
        var completedJobs: [Job] = []
        viewController.onFinished = { completedJobs.append($0) }
        viewController.loadViewIfNeeded()

        viewController.start()
        viewController.start()

        #expect(attempts == 2)
        #expect(savedJobs.count == 1)
        #expect(completedJobs.count == 1)
        #expect(completedJobs.first == savedJobs.first)
    }

    private func makeDraft() -> JobSetupDraft {
        JobSetupDraft(
            basePayAmountText: "",
            currencyCode: "RUB",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: nil,
            payCalculationCycleKind: nil,
            payPeriodAnchorDate: nil
        )
    }
}
