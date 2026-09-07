import Foundation

@MainActor
enum PaycheckResultAssembly {
    static func make(
        comparison: PaycheckComparison,
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale
    ) -> PaycheckResultViewController {
        PaycheckResultViewController(
            comparison: comparison,
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: displayLocale
        )
    }
}
