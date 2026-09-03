import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct JobSetupReviewViewModelTests {
    @Test("Почасовая настройка отображает ставку и сумму")
    func hourlyReviewValues() throws {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "24.50"
        draft.payCalculationCycleKind = .biweekly
        draft.payPeriodAnchorDate = try LocalDate(year: 2026, month: 8, day: 30)

        let viewModel = makeViewModel(draft: draft, decimalInputLocale: Locale(identifier: "en_US"))

        #expect(viewModel.basePayLabel == JobSetupReviewStrings.hourlyPay)
        #expect(viewModel.amount == Decimal(string: "24.50"))
        #expect(viewModel.amountText == "24.50")
        #expect(viewModel.payPeriodLabel == JobSetupReviewStrings.biweeklyPeriod)
        #expect(viewModel.showsPeriodStart)
        #expect(viewModel.canFinish)
    }

    @Test("Фиксированная сумма за смену сохраняется без изменения")
    func fixedPerShiftReviewValues() {
        var draft = makeDraft()
        draft.basePayBasis = .fixedPerShift
        draft.basePayAmountText = "4000"
        draft.payCalculationCycleKind = .perShift

        let viewModel = makeViewModel(draft: draft)

        #expect(viewModel.basePayLabel == JobSetupReviewStrings.fixedPerShiftPay)
        #expect(viewModel.amount == Decimal(string: "4000"))
        #expect(viewModel.payPeriodLabel == JobSetupReviewStrings.perShiftPeriod)
        #expect(viewModel.showsPeriodStart == false)
        #expect(viewModel.canFinish)
    }

    @Test("Period start скрыт для perShift и calendarMonthly")
    func periodStartVisibility() {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"

        for cycle in [PayCalculationCycleKind.perShift, .calendarMonthly] {
            draft.payCalculationCycleKind = cycle
            let viewModel = makeViewModel(draft: draft)
            #expect(viewModel.showsPeriodStart == false)
        }
    }

    @Test("Period start показывается для weekly и biweekly")
    func scheduledPeriodStartVisibility() {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"

        for cycle in [PayCalculationCycleKind.weekly, .biweekly] {
            draft.payCalculationCycleKind = cycle
            let viewModel = makeViewModel(draft: draft)
            #expect(viewModel.showsPeriodStart)
        }
    }

    @Test("Выбор timezone меняет только timezone draft")
    func timeZoneSelectionPreservesOtherValues() {
        let draft = makeDraft()
        let viewModel = makeViewModel(draft: draft)

        #expect(viewModel.selectTimeZone(identifier: "Europe/Stockholm"))
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
        #expect(viewModel.draft.basePayAmountText == draft.basePayAmountText)
        #expect(viewModel.draft.currencyCode == draft.currencyCode)
        #expect(viewModel.draft.payCalculationCycleKind == draft.payCalculationCycleKind)
    }

    @Test("Неполный draft нельзя завершить")
    func incompleteDraftCannotFinish() {
        let viewModel = makeViewModel(draft: makeDraft())

        #expect(viewModel.canFinish == false)
        #expect(throws: JobSetupReviewError.incompleteDraft) {
            try viewModel.makeJob(createdAt: Date(timeIntervalSinceReferenceDate: 10))
        }
    }

    @Test("Hourly setup создаёт Job с initial rate без effective date")
    func createsHourlyJobWithInitialRate() throws {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"
        draft.payCalculationCycleKind = .biweekly
        draft.payPeriodAnchorDate = try LocalDate(year: 2026, month: 8, day: 30)

        let viewModel = makeViewModel(draft: draft)
        let createdAt = Date(timeIntervalSinceReferenceDate: 20)
        let job = try viewModel.makeJob(createdAt: createdAt)

        #expect(job.basePayBasis == .hourly)
        #expect(job.currencyCode == "RUB")
        #expect(job.timeZoneIdentifier == "Europe/Stockholm")
        #expect(job.payRates.count == 1)
        #expect(job.payRates[0].amount == Decimal(500))
        #expect(job.payRates[0].effectiveFrom == nil)
        #expect(job.payCalculationCycle == .scheduled(.biweekly(anchorDate: try #require(draft.payPeriodAnchorDate))))
        #expect(job.createdAt == createdAt)
    }

    @Test("Fixed-per-shift setup создаёт Job с perShift cycle")
    func createsFixedPerShiftJob() throws {
        var draft = makeDraft()
        draft.basePayBasis = .fixedPerShift
        draft.basePayAmountText = "4000"
        draft.payCalculationCycleKind = .perShift

        let job = try makeViewModel(draft: draft).makeJob()

        #expect(job.basePayBasis == .fixedPerShift)
        #expect(job.payRates[0].amount == Decimal(4000))
        #expect(job.payRates[0].effectiveFrom == nil)
        #expect(job.payCalculationCycle == .perShift)
    }

    @Test("Успешное сохранение возвращает Job и блокирует повтор")
    func successfulSaveReturnsJobAndIgnoresDuplicate() throws {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"
        draft.payCalculationCycleKind = .perShift
        var savedJobs: [Job] = []
        let viewModel = JobSetupReviewViewModel(
            draft: draft,
            saveJob: { job in
                savedJobs.append(job)
                return .success(())
            }
        )
        let createdAt = Date(timeIntervalSinceReferenceDate: 20)

        let result = viewModel.save(createdAt: createdAt)
        let savedJob = try #require(savedJobs.first)
        #expect(result == .saved(savedJob))
        #expect(savedJob.createdAt == createdAt)

        #expect(viewModel.save(createdAt: createdAt) == .ignored)
        #expect(savedJobs.count == 1)
    }

    @Test("Ошибка persistence разрешает повторную попытку")
    func persistenceFailureAllowsRetry() throws {
        var draft = makeDraft()
        draft.basePayBasis = .fixedPerShift
        draft.basePayAmountText = "4000"
        draft.payCalculationCycleKind = .perShift
        var attempts = 0
        var savedJobs: [Job] = []
        let viewModel = JobSetupReviewViewModel(
            draft: draft,
            saveJob: { job in
                attempts += 1
                if attempts == 1 {
                    return .failure(.persistence)
                }
                savedJobs.append(job)
                return .success(())
            }
        )
        let createdAt = Date(timeIntervalSinceReferenceDate: 21)

        #expect(viewModel.save(createdAt: createdAt) == .failed(.persistence))
        #expect(viewModel.isSaving == false)
        let retryResult = viewModel.save(createdAt: createdAt)
        let savedJob = try #require(savedJobs.first)
        #expect(retryResult == .saved(savedJob))
        #expect(attempts == 2)
        #expect(viewModel.isSaving)
    }

    @Test("Неполный draft не вызывает сохранение")
    func invalidDraftDoesNotSave() {
        var saveCalls = 0
        let viewModel = JobSetupReviewViewModel(
            draft: makeDraft(),
            saveJob: { _ in
                saveCalls += 1
                return .success(())
            }
        )

        #expect(viewModel.save() == .invalid)
        #expect(saveCalls == 0)
    }

    @Test("Ошибка создания Job маппится в invalidDraft")
    func jobConstructionFailureMapsToInvalidDraft() {
        var draft = makeDraft()
        draft.basePayBasis = .hourly
        draft.basePayAmountText = "500"
        draft.payCalculationCycleKind = .perShift
        draft.currencyCode = "EURO"
        var saveCalls = 0
        let viewModel = JobSetupReviewViewModel(
            draft: draft,
            saveJob: { _ in
                saveCalls += 1
                return .success(())
            }
        )

        #expect(viewModel.canFinish)
        #expect(viewModel.save() == .failed(.invalidDraft))
        #expect(saveCalls == 0)
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

    private func makeViewModel(
        draft: JobSetupDraft,
        decimalInputLocale: Locale = .current
    ) -> JobSetupReviewViewModel {
        JobSetupReviewViewModel(
            draft: draft,
            decimalInputLocale: decimalInputLocale,
            saveJob: { _ in .success(()) }
        )
    }
}
