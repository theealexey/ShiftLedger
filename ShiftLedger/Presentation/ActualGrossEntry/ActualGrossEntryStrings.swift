import Foundation

enum ActualGrossEntryStrings {
    static var title: String { String(localized: "actualGrossEntry.title", table: "Localizable") }
    static var question: String { String(localized: "actualGrossEntry.question", table: "Localizable") }
    static var supporting: String { String(localized: "actualGrossEntry.supporting", table: "Localizable") }
    static var amount: String { String(localized: "actualGrossEntry.amount", table: "Localizable") }
    static var compare: String { String(localized: "actualGrossEntry.compare", table: "Localizable") }
    static var invalidAmount: String {
        String(localized: "actualGrossEntry.validation.invalid", table: "Localizable")
    }
}
