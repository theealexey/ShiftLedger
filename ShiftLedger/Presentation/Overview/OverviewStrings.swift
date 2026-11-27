import Foundation

enum OverviewStrings {
    static var unpaidBreakDetail: String {
        String(localized: "overview.shift.unpaidBreakDetail", table: "Localizable")
    }
    static func paidDuration(_ duration: String) -> String {
        String(format: String(localized: "overview.shift.paidDuration", table: "Localizable"), duration)
    }

    static var shiftSectionPrefix: String {
        String(localized: "overview.shiftSection.prefix", table: "Localizable")
    }
    static var allShiftHistory: String {
        String(localized: "overview.ledgerHistory.title", table: "Localizable")
    }
    static var shiftHistoryCountTitle: String {
        String(localized: "overview.ledgerHistory.countTitle", table: "Localizable")
    }
    static var noSavedShifts: String {
        String(localized: "overview.ledgerHistory.empty", table: "Localizable")
    }
    static var receiptBrand: String { String(localized: "overview.receipt.brand", table: "Localizable") }
    static var receiptSubtitle: String { String(localized: "overview.receipt.subtitle", table: "Localizable") }
    static var historyScope: String { String(localized: "overview.receipt.historyScope", table: "Localizable") }
    static var exactAmountDetail: String { String(localized: "overview.shift.exactAmountDetail", table: "Localizable") }
    static var exactContribution: String { String(localized: "overview.receipt.exactContribution", table: "Localizable") }
    static var exactTotal: String { String(localized: "overview.receipt.exactTotal", table: "Localizable") }
    static var displayedTotal: String { String(localized: "overview.receipt.displayedTotal", table: "Localizable") }
    static var roundedForDisplay: String { String(localized: "overview.receipt.roundedForDisplay", table: "Localizable") }

    static func expectedGrossContext(currencyCode: String) -> String {
        String(format: String(localized: "overview.expectedGross.context", table: "Localizable"), currencyCode)
    }
    static var title: String { String(localized: "overview.title", table: "Localizable") }
    static var expectedGross: String { String(localized: "overview.expectedGross", table: "Localizable") }
    static var shiftHistoryEmpty: String {
        String(localized: "overview.shiftHistory.empty", table: "Localizable")
    }
    static var payBasis: String { String(localized: "overview.shift.payBasis", table: "Localizable") }
    static var expandShift: String { String(localized: "overview.shift.expand", table: "Localizable") }
    static var selectShift: String { String(localized: "overview.shift.select", table: "Localizable") }
    static var collapseShift: String { String(localized: "overview.shift.collapse", table: "Localizable") }
    static var expanded: String { String(localized: "overview.shift.expanded", table: "Localizable") }
    static var collapsed: String { String(localized: "overview.shift.collapsed", table: "Localizable") }
    static var checkPaycheck: String { String(localized: "overview.checkPaycheck", table: "Localizable") }
    static var addShift: String { String(localized: "overview.addShift", table: "Localizable") }
    static var workTypes: String { String(localized: "overview.workTypes", table: "Localizable") }
    static var editShift: String { String(localized: "overview.editShift", table: "Localizable") }
    static var previousPeriod: String { String(localized: "overview.previousPeriod", table: "Localizable") }
    static var nextPeriod: String { String(localized: "overview.nextPeriod", table: "Localizable") }
    static var emptyTitle: String { String(localized: "overview.empty.title", table: "Localizable") }
    static var emptyMessage: String { String(localized: "overview.empty.message", table: "Localizable") }
    static var loadingErrorTitle: String { String(localized: "overview.error.loading.title", table: "Localizable") }
    static var loadingErrorMessage: String { String(localized: "overview.error.loading.message", table: "Localizable") }
    static var calculationErrorTitle: String { String(localized: "overview.error.calculation.title", table: "Localizable") }
    static var calculationErrorMessage: String { String(localized: "overview.error.calculation.message", table: "Localizable") }
    static var retry: String { String(localized: "overview.retry", table: "Localizable") }
}

// Shifts history controls and filter form.
enum ShiftHistoryStrings {
    static var filters: String { String(localized: "shifts.history.filters") }
    static var sort: String { String(localized: "shifts.history.sort") }
    static var sortCompact: String { String(localized: "shifts.history.sortCompact") }
    static var newest: String { String(localized: "shifts.history.newest") }
    static var oldest: String { String(localized: "shifts.history.oldest") }
    static var highest: String { String(localized: "shifts.history.highest") }
    static var lowest: String { String(localized: "shifts.history.lowest") }
    static var noMatches: String { String(localized: "shifts.history.noMatches") }
    static var reset: String { String(localized: "shifts.history.reset") }
    static var apply: String { String(localized: "shifts.history.apply") }
    static var cancel: String { String(localized: "shifts.history.cancel") }
    static var date: String { String(localized: "shifts.history.date") }
    static var allDates: String { String(localized: "shifts.history.allDates") }
    static var thisMonth: String { String(localized: "shifts.history.thisMonth") }
    static var custom: String { String(localized: "shifts.history.custom") }
    static var start: String { String(localized: "shifts.history.start") }
    static var end: String { String(localized: "shifts.history.end") }
    static var workType: String { String(localized: "shifts.history.workType") }
    static var allTypes: String { String(localized: "shifts.history.allTypes") }
    static var minimum: String { String(localized: "shifts.history.minimum") }
    static var maximum: String { String(localized: "shifts.history.maximum") }
    static var invalidDate: String { String(localized: "shifts.history.invalidDate") }
    static var invalidAmount: String { String(localized: "shifts.history.invalidAmount") }
    static var invalidRange: String { String(localized: "shifts.history.invalidRange") }
    static func active(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "shifts.history.active"), count)
    }
    static func activeTitle(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "shifts.history.activeTitle"), count)
    }
    static func count(visible: Int, total: Int) -> String {
        String.localizedStringWithFormat(String(localized: "shifts.history.count"), visible, total)
    }
    static func archived(_ name: String) -> String {
        String.localizedStringWithFormat(String(localized: "shifts.history.archived"), name)
    }
    static func amount(_ currency: String) -> String {
        String.localizedStringWithFormat(String(localized: "shifts.history.amount"), currency)
    }

    static func title(for sort: ShiftHistoryQuery.Sort) -> String {
        switch sort {
        case .newest: newest
        case .oldest: oldest
        case .highest: highest
        case .lowest: lowest
        }
    }
}
