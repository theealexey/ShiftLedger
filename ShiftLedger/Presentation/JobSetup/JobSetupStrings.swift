import Foundation

enum JobSetupStrings {
    static var brandName: String { String(localized: "app.brandName", table: "Localizable") }
    static var stepIndicator: String { String(localized: "jobSetup.stepIndicator", table: "Localizable") }
    static var stepIndicatorAccessibilityLabel: String { String(localized: "jobSetup.stepIndicator.accessibilityLabel", table: "Localizable") }
    static var step1Title: String { String(localized: "jobSetup.step1.title", table: "Localizable") }
    static var step1Subtitle: String { String(localized: "jobSetup.step1.subtitle", table: "Localizable") }
    static var nameTitle: String { String(localized: "jobSetup.name.title", table: "Localizable") }
    static var namePlaceholder: String { String(localized: "jobSetup.name.placeholder", table: "Localizable") }
    static var nameAccessibilityHint: String { String(localized: "jobSetup.name.accessibilityHint", table: "Localizable") }
    static var continueTitle: String { String(localized: "common.continue", table: "Localizable") }
}
