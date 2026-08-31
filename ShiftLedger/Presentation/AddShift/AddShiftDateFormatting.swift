import Foundation

enum AddShiftDateFormatting {
    static func string(for date: Date, timeZoneIdentifier: String, locale: Locale) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func accessibilityString(for date: Date, timeZoneIdentifier: String, locale: Locale) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
