import Foundation

enum JobSelectionStrings {
    static var title: String { String(localized: "jobSelection.title", table: "Localizable") }
    static var active: String { String(localized: "jobSelection.active", table: "Localizable") }
    static var archived: String { String(localized: "jobSelection.archived", table: "Localizable") }
    static var unnamed: String { String(localized: "jobSelection.unnamed", table: "Localizable") }
    static var archivedStatus: String { String(localized: "jobSelection.archivedStatus", table: "Localizable") }
    static var noActive: String { String(localized: "jobSelection.noActive", table: "Localizable") }
    static var errorTitle: String { String(localized: "jobSelection.error.title", table: "Localizable") }
    static var errorMessage: String { String(localized: "jobSelection.error.message", table: "Localizable") }
    static var retry: String { String(localized: "application.startupError.retry", table: "Localizable") }
    static var cancel: String { String(localized: "common.cancel", table: "Localizable") }
}
