import Foundation

enum TimeZoneDisplayName {
    static func value(for identifier: String, locale: Locale) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else {
            return identifier
        }

        guard identifier.contains("/") else {
            return identifier
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "VVV"

        let city = formatter.string(from: Date(timeIntervalSince1970: 0))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if city.isEmpty == false {
            return city
        }

        return identifier.split(separator: "/").last
            .map(String.init)?
            .replacingOccurrences(of: "_", with: " ") ?? identifier
    }
}
