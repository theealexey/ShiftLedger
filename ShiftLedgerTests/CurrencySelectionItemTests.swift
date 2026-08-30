import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct CurrencySelectionItemTests {
    private let englishLocale = Locale(identifier: "en")

    @Test("Foundation ISO currencies сортируются по code")
    func sortsAvailableCurrenciesByCode() {
        let currencies = CurrencySelectionItem.available(displayLocale: englishLocale)

        #expect(currencies.isEmpty == false)
        #expect(currencies.allSatisfy { Locale.Currency($0.code).isISOCurrency })
        #expect(zip(currencies, currencies.dropFirst()).allSatisfy { $0.code < $1.code })
        #expect(Set(currencies.map(\.code)).isSuperset(of: ["EUR", "USD", "SEK"]))
    }

    @Test("Foundation локализует имя валюты для display locale")
    func localizesCurrencyNameForDisplayLocale() {
        let englishEuro = CurrencySelectionItem(code: "EUR", displayLocale: Locale(identifier: "en"))
        let russianEuro = CurrencySelectionItem(code: "EUR", displayLocale: Locale(identifier: "ru"))

        #expect(englishEuro.localizedName == "Euro")
        #expect(russianEuro.localizedName == "евро")
    }

    @Test("Пустой поиск сохраняет список")
    func emptyQueryPreservesCurrencies() {
        let currencies = makeCurrencies()

        #expect(CurrencySelectionItem.filtered(currencies, query: "", locale: englishLocale) == currencies)
    }

    @Test("Поиск находит ISO code без учёта регистра")
    func findsCurrencyByCode() {
        let result = CurrencySelectionItem.filtered(makeCurrencies(), query: "eUr", locale: englishLocale)

        #expect(result.map(\.code) == ["EUR"])
    }

    @Test("Поиск находит локализованное имя без учёта диакритики")
    func findsCurrencyByLocalizedName() {
        let currencies = [
            CurrencySelectionItem(code: "EUR", localizedName: "Евро"),
            CurrencySelectionItem(code: "SEK", localizedName: "Шведская крона")
        ]

        let result = CurrencySelectionItem.filtered(currencies, query: "евро", locale: Locale(identifier: "ru"))

        #expect(result.map(\.code) == ["EUR"])
    }

    @Test("Поиск находит валюту по части английского имени")
    func findsCurrencyByPartialLocalizedName() {
        let result = CurrencySelectionItem.filtered(makeCurrencies(), query: "dollar", locale: englishLocale)

        #expect(result.map(\.code) == ["USD"])
    }

    @Test("Поиск без совпадений возвращает пустой список")
    func returnsNoCurrenciesWhenQueryDoesNotMatch() {
        let result = CurrencySelectionItem.filtered(makeCurrencies(), query: "not-a-currency", locale: englishLocale)

        #expect(result.isEmpty)
    }

    private func makeCurrencies() -> [CurrencySelectionItem] {
        [
            CurrencySelectionItem(code: "EUR", localizedName: "Euro"),
            CurrencySelectionItem(code: "SEK", localizedName: "Swedish Krona"),
            CurrencySelectionItem(code: "USD", localizedName: "US Dollar")
        ]
    }
}
