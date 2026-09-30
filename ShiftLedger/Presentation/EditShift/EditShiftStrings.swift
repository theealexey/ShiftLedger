import Foundation

enum EditShiftStrings {
    static var title: String { String(localized: "editShift.title", table: "Localizable") }
    static var save: String { String(localized: "editShift.save", table: "Localizable") }
    static var delete: String { String(localized: "editShift.delete", table: "Localizable") }
    static var deleteConfirmationTitle: String {
        String(localized: "editShift.delete.confirmation.title", table: "Localizable")
    }
    static var deleteConfirmationMessage: String {
        String(localized: "editShift.delete.confirmation.message", table: "Localizable")
    }
    static var deleteErrorTitle: String {
        String(localized: "editShift.delete.error.title", table: "Localizable")
    }
    static var deleteErrorMessage: String {
        String(localized: "editShift.delete.error.message", table: "Localizable")
    }
    static var overlapTitle: String {
        String(localized: "editShift.error.overlap.title", table: "Localizable")
    }
    static var overlapMessage: String {
        String(localized: "editShift.error.overlap.message", table: "Localizable")
    }
    static var genericErrorTitle: String {
        String(localized: "editShift.error.generic.title", table: "Localizable")
    }
    static var genericErrorMessage: String {
        String(localized: "editShift.error.generic.message", table: "Localizable")
    }
    static var alertOK: String { String(localized: "common.ok", table: "Localizable") }
    static var cancel: String { String(localized: "common.cancel", table: "Localizable") }
}
