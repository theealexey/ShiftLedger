import Foundation

enum PayRateHistoryStrings {
    static var title: String {
        String(localized: "payRateHistory.title", table: "Localizable")
    }

    static var initialRate: String {
        String(localized: "payRateHistory.initialRate", table: "Localizable")
    }

    static func effectiveFrom(_ date: String, locale: Locale) -> String {
        String(
            format: String(localized: "payRateHistory.effectiveFrom", table: "Localizable"),
            locale: locale,
            date
        )
    }

    static func accessibilityHourlyRate(_ amount: String, locale: Locale) -> String {
        String(
            format: String(localized: "payRateHistory.accessibility.hourlyRate", table: "Localizable"),
            locale: locale,
            amount
        )
    }

    static func accessibilityPerShiftRate(_ amount: String, locale: Locale) -> String {
        String(
            format: String(localized: "payRateHistory.accessibility.perShiftRate", table: "Localizable"),
            locale: locale,
            amount
        )
    }

    static func accessibilityEffectiveFrom(
        rate: String,
        date: String,
        locale: Locale
    ) -> String {
        String(
            format: String(
                localized: "payRateHistory.accessibility.effectiveFrom",
                table: "Localizable"
            ),
            locale: locale,
            rate,
            date
        )
    }

    static func accessibilityInitialRate(_ rate: String, locale: Locale) -> String {
        String(
            format: String(
                localized: "payRateHistory.accessibility.initialRate",
                table: "Localizable"
            ),
            locale: locale,
            rate
        )
    }
}
