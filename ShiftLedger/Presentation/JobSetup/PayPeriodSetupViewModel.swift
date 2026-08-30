import Foundation

@MainActor
final class PayPeriodSetupViewModel {
    private(set) var draft: JobSetupDraft

    init(draft: JobSetupDraft) {
        self.draft = draft
    }

    var selectedFrequency: PayPeriodFrequency? {
        draft.payPeriodFrequency
    }

    var anchorDate: LocalDate? {
        draft.payPeriodAnchorDate
    }

    var requiresAnchorDate: Bool {
        switch draft.payPeriodFrequency {
        case .weekly, .biweekly:
            true
        case .calendarMonthly, nil:
            false
        }
    }

    var canContinue: Bool {
        switch draft.payPeriodFrequency {
        case .weekly, .biweekly:
            draft.payPeriodAnchorDate != nil
        case .calendarMonthly:
            true
        case nil:
            false
        }
    }

    var payPeriodSchedule: PayPeriodSchedule? {
        switch (draft.payPeriodFrequency, draft.payPeriodAnchorDate) {
        case let (.weekly, anchorDate?):
            return .weekly(anchorDate: anchorDate)
        case let (.biweekly, anchorDate?):
            return .biweekly(anchorDate: anchorDate)
        case (.calendarMonthly, _):
            return .calendarMonthly
        case (nil, _), (.weekly, nil), (.biweekly, nil):
            return nil
        }
    }

    func selectFrequency(_ frequency: PayPeriodFrequency) {
        draft.payPeriodFrequency = frequency
    }

    func selectAnchorDate(_ date: LocalDate) {
        draft.payPeriodAnchorDate = date
    }
}
