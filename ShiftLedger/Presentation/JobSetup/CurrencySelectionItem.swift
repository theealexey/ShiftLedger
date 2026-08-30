import Foundation

struct CurrencySelectionItem: Equatable {
    let code: String
    let localizedName: String

    init(code: String, displayLocale: Locale) {
        self.code = code
        localizedName = displayLocale.localizedString(forCurrencyCode: code) ?? code
    }

    init(code: String, localizedName: String) {
        self.code = code
        self.localizedName = localizedName
    }

    static func available(displayLocale: Locale) -> [CurrencySelectionItem] {
        Locale.commonISOCurrencyCodes
            .filter { Locale.Currency($0).isISOCurrency }
            .map { CurrencySelectionItem(code: $0, displayLocale: displayLocale) }
            .sorted { $0.code < $1.code }
    }

    static func filtered(
        _ currencies: [CurrencySelectionItem],
        query: String,
        locale: Locale
    ) -> [CurrencySelectionItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedQuery.isEmpty == false else {
            return currencies
        }

        return currencies.filter { currency in
            currency.code.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: locale
            ) != nil || currency.localizedName.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: locale
            ) != nil
        }
    }

    static var applicationDisplayLocale: Locale {
        let identifier = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
        return Locale(identifier: identifier)
    }
}
