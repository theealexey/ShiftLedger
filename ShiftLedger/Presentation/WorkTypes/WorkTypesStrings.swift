import Foundation

enum WorkTypesStrings {
    static var title: String { String(localized: "workTypes.title", table: "Localizable") }
    static var add: String { String(localized: "workTypes.add", table: "Localizable") }
    static var unnamed: String { String(localized: "workTypes.unnamed", table: "Localizable") }
    static var hourly: String { String(localized: "workTypes.payBasis.hourly", table: "Localizable") }
    static var fixedPerShift: String {
        String(localized: "workTypes.payBasis.fixedPerShift", table: "Localizable")
    }
    static var actionsHint: String { String(localized: "workTypes.actionsHint", table: "Localizable") }
    static var rename: String { String(localized: "workTypes.action.rename", table: "Localizable") }
    static var changePayRate: String { String(localized: "workTypes.action.changePayRate", table: "Localizable") }
    static var payRateHistory: String {
        String(localized: "workTypes.action.payRateHistory", table: "Localizable")
    }
    static var cancel: String { String(localized: "common.cancel", table: "Localizable") }
    static var ok: String { String(localized: "common.ok", table: "Localizable") }
    static var activeSection: String { String(localized: "workTypes.section.active", table: "Localizable") }
    static var archivedSection: String { String(localized: "workTypes.section.archived", table: "Localizable") }
    static var archivedStatus: String { String(localized: "workTypes.archived.accessibilityStatus", table: "Localizable") }
    static var archive: String { String(localized: "workTypes.action.archive", table: "Localizable") }
    static var archiveConfirmationTitle: String { String(localized: "workTypes.archive.confirmation.title", table: "Localizable") }
    static var archiveConfirmationMessage: String { String(localized: "workTypes.archive.confirmation.message", table: "Localizable") }
    static var archiveErrorTitle: String { String(localized: "workTypes.archive.error.title", table: "Localizable") }
    static var archiveErrorMessage: String { String(localized: "workTypes.archive.error.message", table: "Localizable") }
}
