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

    var requiresAnchorDate: Bool {
        switch draft.payCalculationCycleKind {
        case .weekly, .biweekly:
            true
        case .perShift, .calendarMonthly, nil:
            false
        }
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

    var payCalculationCycle: PayCalculationCycle? {
        switch (draft.payCalculationCycleKind, draft.payPeriodAnchorDate) {
        case (.perShift, _):
            return .perShift
        case let (.weekly, anchorDate?):
            return .scheduled(.weekly(anchorDate: anchorDate))
        case let (.biweekly, anchorDate?):
            return .scheduled(.biweekly(anchorDate: anchorDate))
        case (.calendarMonthly, _):
            return .scheduled(.calendarMonthly)
        case (nil, _), (.weekly, nil), (.biweekly, nil):
            return nil
        }
    }

    func selectCycleKind(_ kind: PayCalculationCycleKind) {
        draft.payCalculationCycleKind = kind
    }

    func selectAnchorDate(_ date: LocalDate) {
        draft.payPeriodAnchorDate = date
    }
}
