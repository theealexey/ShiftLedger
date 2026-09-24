import Foundation

enum ChangePayRateStrings {
    static var title: String { String(localized: "changePayRate.title", table: "Localizable") }
    static var save: String { String(localized: "changePayRate.save", table: "Localizable") }
    static var unnamed: String { String(localized: "changePayRate.unnamed", table: "Localizable") }
    static var hourly: String { String(localized: "changePayRate.hourly", table: "Localizable") }
    static var fixedPerShift: String { String(localized: "changePayRate.fixedPerShift", table: "Localizable") }
    static var newHourlyRate: String { String(localized: "changePayRate.newHourlyRate", table: "Localizable") }
    static var newPerShiftAmount: String { String(localized: "changePayRate.newPerShiftAmount", table: "Localizable") }
    static var amountHint: String { String(localized: "changePayRate.amount.hint", table: "Localizable") }
    static var currency: String { String(localized: "changePayRate.currency", table: "Localizable") }
    static var effectiveDate: String { String(localized: "changePayRate.effectiveDate", table: "Localizable") }
    static var effectiveDateExplanation: String {
        String(localized: "changePayRate.effectiveDate.explanation", table: "Localizable")
    }
    static var timeZone: String { String(localized: "changePayRate.timeZone", table: "Localizable") }
    static var duplicateDate: String {
        String(localized: "changePayRate.effectiveDate.duplicate", table: "Localizable")
    }
    static var errorTitle: String { String(localized: "changePayRate.error.title", table: "Localizable") }
    static var errorMessage: String { String(localized: "changePayRate.error.message", table: "Localizable") }
    static var ok: String { String(localized: "common.ok", table: "Localizable") }
}
