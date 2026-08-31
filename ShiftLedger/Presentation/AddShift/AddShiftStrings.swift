import Foundation

enum AddShiftStrings {
    static var title: String { String(localized: "addShift.title", table: "Localizable") }
    static var save: String { String(localized: "addShift.save", table: "Localizable") }
    static var start: String { String(localized: "addShift.start", table: "Localizable") }
    static var end: String { String(localized: "addShift.end", table: "Localizable") }
    static var select: String { String(localized: "addShift.select", table: "Localizable") }
    static var timeZonePrefix: String { String(localized: "addShift.timeZone.prefix", table: "Localizable") }
    static var unpaidBreak: String { String(localized: "addShift.unpaidBreak", table: "Localizable") }
    static var breakStart: String { String(localized: "addShift.breakStart", table: "Localizable") }
    static var breakEnd: String { String(localized: "addShift.breakEnd", table: "Localizable") }
    static var shiftStartPickerTitle: String { String(localized: "addShift.picker.shiftStart", table: "Localizable") }
    static var shiftEndPickerTitle: String { String(localized: "addShift.picker.shiftEnd", table: "Localizable") }
    static var breakStartPickerTitle: String { String(localized: "addShift.picker.breakStart", table: "Localizable") }
    static var breakEndPickerTitle: String { String(localized: "addShift.picker.breakEnd", table: "Localizable") }
    static var cancel: String { String(localized: "common.cancel", table: "Localizable") }
    static var done: String { String(localized: "common.done", table: "Localizable") }
    static var overlapTitle: String { String(localized: "addShift.error.overlap.title", table: "Localizable") }
    static var overlapMessage: String { String(localized: "addShift.error.overlap.message", table: "Localizable") }
    static var genericErrorTitle: String { String(localized: "addShift.error.generic.title", table: "Localizable") }
    static var genericErrorMessage: String { String(localized: "addShift.error.generic.message", table: "Localizable") }
    static var alertOK: String { String(localized: "common.ok", table: "Localizable") }

    static var endAfterStartError: String { String(localized: "addShift.validation.endAfterStart", table: "Localizable") }
    static var durationError: String { String(localized: "addShift.validation.duration", table: "Localizable") }
    static var breakEndAfterStartError: String { String(localized: "addShift.validation.breakEndAfterStart", table: "Localizable") }
    static var breakInsideShiftError: String { String(localized: "addShift.validation.breakInsideShift", table: "Localizable") }
    static var breakWholeShiftError: String { String(localized: "addShift.validation.breakWholeShift", table: "Localizable") }
}
