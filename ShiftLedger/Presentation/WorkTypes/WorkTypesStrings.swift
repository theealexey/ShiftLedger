import Foundation

enum WorkTypesStrings {
    static var title: String { String(localized: "workTypes.title", table: "Localizable") }
    static var add: String { String(localized: "workTypes.add", table: "Localizable") }
    static var unnamed: String { String(localized: "workTypes.unnamed", table: "Localizable") }
    static var hourly: String { String(localized: "workTypes.payBasis.hourly", table: "Localizable") }
    static var fixedPerShift: String {
        String(localized: "workTypes.payBasis.fixedPerShift", table: "Localizable")
    }
}
