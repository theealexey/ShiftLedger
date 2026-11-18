import Foundation

enum PaycheckResultStrings {
    static var title: String { String(localized: "paycheckResult.title", table: "Localizable") }
    static var expected: String { String(localized: "paycheckResult.expected", table: "Localizable") }
    static var actual: String { String(localized: "paycheckResult.actual", table: "Localizable") }
    static var difference: String { String(localized: "paycheckResult.difference", table: "Localizable") }
    static var lower: String { String(localized: "paycheckResult.lower", table: "Localizable") }
    static var equal: String { String(localized: "paycheckResult.equal", table: "Localizable") }
    static var higher: String { String(localized: "paycheckResult.higher", table: "Localizable") }
    static var breakdownTitle: String {
        String(localized: "paycheckResult.breakdown.title", table: "Localizable")
    }
    static var breakdownEmpty: String {
        String(localized: "paycheckResult.breakdown.empty", table: "Localizable")
    }
    static var paidTime: String { String(localized: "paycheckResult.shift.paidTime", table: "Localizable") }
    static var rate: String { String(localized: "paycheckResult.shift.rate", table: "Localizable") }
    static var shiftExpected: String {
        String(localized: "paycheckResult.shift.expected", table: "Localizable")
    }
    static var unnamedWorkType: String {
        String(localized: "paycheckResult.shift.unnamedWorkType", table: "Localizable")
    }
    static var rateHour: String { String(localized: "paycheckResult.rate.hour", table: "Localizable") }
    static var rateShift: String { String(localized: "paycheckResult.rate.shift", table: "Localizable") }
    static var durationHour: String {
        String(localized: "paycheckResult.duration.hour", table: "Localizable")
    }
    static var durationMinute: String {
        String(localized: "paycheckResult.duration.minute", table: "Localizable")
    }
    static var durationSecond: String {
        String(localized: "paycheckResult.duration.second", table: "Localizable")
    }
    static var durationLessThanSecond: String {
        String(
            localized: "paycheckResult.duration.lessThanSecond",
            table: "Localizable"
        )
    }
    static var showExactAmounts: String {
        String(localized: "paycheckResult.exact.show", table: "Localizable")
    }
    static var hideExactAmounts: String {
        String(localized: "paycheckResult.exact.hide", table: "Localizable")
    }
    static var exactRate: String {
        String(localized: "paycheckResult.exact.rate", table: "Localizable")
    }
    static var exactContribution: String {
        String(localized: "paycheckResult.exact.contribution", table: "Localizable")
    }
    static var approximationNote: String {
        String(localized: "paycheckResult.approximation.note", table: "Localizable")
    }

    static func approximate(_ amount: String) -> String {
        String(format: String(localized: "paycheckResult.approximation.value", table: "Localizable"), amount)
    }

    static func belowMinorUnit(_ bound: String, negative: Bool, isDifference: Bool) -> String {
        let format = if isDifference {
            if negative {
                String(localized: "paycheckResult.tiny.negative", table: "Localizable")
            } else {
                String(localized: "paycheckResult.tiny.positive", table: "Localizable")
            }
        } else {
            String(localized: "paycheckResult.tiny.amount", table: "Localizable")
        }
        return String(format: format, bound)
    }

    static var done: String { String(localized: "common.done", table: "Localizable") }
}
