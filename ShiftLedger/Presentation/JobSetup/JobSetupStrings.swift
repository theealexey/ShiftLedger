import Foundation

enum JobSetupStrings {
    static var brandName: String { String(localized: "app.brandName", table: "Localizable") }
    static var title: String { String(localized: "jobSetup.title", table: "Localizable") }
    static var subtitle: String { String(localized: "jobSetup.subtitle", table: "Localizable") }
    static var nameTitle: String { String(localized: "jobSetup.name.title", table: "Localizable") }
    static var namePlaceholder: String { String(localized: "jobSetup.name.placeholder", table: "Localizable") }
    static var nameAccessibilityHint: String { String(localized: "jobSetup.name.accessibilityHint", table: "Localizable") }
    static var currencyTitle: String { String(localized: "jobSetup.currency.title", table: "Localizable") }
    static var currencyAccessibilityHint: String { String(localized: "jobSetup.currency.accessibilityHint", table: "Localizable") }
    static var timeZoneTitle: String { String(localized: "jobSetup.timeZone.title", table: "Localizable") }
    static var timeZoneAccessibilityHint: String { String(localized: "jobSetup.timeZone.accessibilityHint", table: "Localizable") }
    static var continueTitle: String { String(localized: "common.continue", table: "Localizable") }
}
