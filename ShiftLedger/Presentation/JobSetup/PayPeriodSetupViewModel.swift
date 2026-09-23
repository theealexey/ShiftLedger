import Foundation

@MainActor
final class PayPeriodSetupViewModel {
    private(set) var draft: JobSetupDraft

    init(draft: JobSetupDraft) {
        self.draft = draft
    }

    var selectedCycleKind: PayCalculationCycleKind? {
        draft.payCalculationCycleKind
    }

    var anchorDate: LocalDate? {
        draft.payPeriodAnchorDate
    }

    var canContinue: Bool {
        switch draft.payCalculationCycleKind {
        case .perShift, .calendarMonthly:
            true
        case .weekly, .biweekly:
            draft.payPeriodAnchorDate != nil
        case nil:
            false
        }
    }

    func selectCycleKind(_ kind: PayCalculationCycleKind) {
        draft.payCalculationCycleKind = kind
    }

    func selectAnchorDate(_ date: LocalDate) {
        draft.payPeriodAnchorDate = date
    }
}
