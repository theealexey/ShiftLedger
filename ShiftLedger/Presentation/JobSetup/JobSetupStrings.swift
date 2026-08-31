import Foundation

enum JobSetupStrings {
    static var brandName: String { String(localized: "app.brandName", table: "Localizable") }
    static var stepIndicator: String { String(localized: "jobSetup.stepIndicator", table: "Localizable") }
    static var stepIndicatorAccessibilityLabel: String { String(localized: "jobSetup.stepIndicator.accessibilityLabel", table: "Localizable") }
    static var step1Title: String { String(localized: "jobSetup.step1.title", table: "Localizable") }
    static var step1Subtitle: String { String(localized: "jobSetup.step1.subtitle", table: "Localizable") }
    static var hourlyBasis: String { String(localized: "jobSetup.basePay.hourly", table: "Localizable") }
    static var fixedPerShiftBasis: String { String(localized: "jobSetup.basePay.fixedPerShift", table: "Localizable") }
    static var hourlyAmountTitle: String { String(localized: "jobSetup.basePay.hourly.amountTitle", table: "Localizable") }
    static var fixedPerShiftAmountTitle: String { String(localized: "jobSetup.basePay.fixedPerShift.amountTitle", table: "Localizable") }
    static var basePayAmountAccessibilityHint: String { String(localized: "jobSetup.basePay.amount.accessibilityHint", table: "Localizable") }
    static var currencyTitle: String { String(localized: "jobSetup.currency.title", table: "Localizable") }
    static var currencyAccessibilityHint: String { String(localized: "jobSetup.currency.accessibilityHint", table: "Localizable") }
    static var continueTitle: String { String(localized: "common.continue", table: "Localizable") }
}
