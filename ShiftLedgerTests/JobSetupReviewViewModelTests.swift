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

        let viewModel = JobSetupReviewViewModel(draft: draft, decimalInputLocale: Locale(identifier: "en_US"))

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

        let viewModel = JobSetupReviewViewModel(draft: draft)

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
            let viewModel = JobSetupReviewViewModel(draft: draft)
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
            let viewModel = JobSetupReviewViewModel(draft: draft)
            #expect(viewModel.showsPeriodStart)
        }
    }

    @Test("Выбор timezone меняет только timezone draft")
    func timeZoneSelectionPreservesOtherValues() {
        let draft = makeDraft()
        let viewModel = JobSetupReviewViewModel(draft: draft)

        #expect(viewModel.selectTimeZone(identifier: "Europe/Stockholm"))
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
        #expect(viewModel.draft.basePayAmountText == draft.basePayAmountText)
        #expect(viewModel.draft.currencyCode == draft.currencyCode)
        #expect(viewModel.draft.payCalculationCycleKind == draft.payCalculationCycleKind)
    }

    @Test("Неполный draft нельзя завершить")
    func incompleteDraftCannotFinish() {
        let viewModel = JobSetupReviewViewModel(draft: makeDraft())

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

        let viewModel = JobSetupReviewViewModel(draft: draft)
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

        let job = try JobSetupReviewViewModel(draft: draft).makeJob()

        #expect(job.basePayBasis == .fixedPerShift)
        #expect(job.payRates[0].amount == Decimal(4000))
        #expect(job.payRates[0].effectiveFrom == nil)
        #expect(job.payCalculationCycle == .perShift)
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
