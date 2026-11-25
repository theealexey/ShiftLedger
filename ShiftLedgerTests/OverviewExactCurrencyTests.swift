import Foundation
import Testing
@testable import ShiftLedger

struct OverviewExactCurrencyTests {
    @Test("Exact currency preserves grouping, placement, and currency-specific fraction digits", arguments: [
        ("SEK", "1234.5", "SEK\u{00A0}1,234.50", "1\u{00A0}234,50\u{00A0}SEK"),
        ("EUR", "1234.5", "€1,234.50", "1\u{00A0}234,50\u{00A0}€"),
        ("JPY", "1234", "¥1,234", "1\u{00A0}234\u{00A0}¥"),
        ("KWD", "1234.5", "KWD\u{00A0}1,234.500", "1\u{00A0}234,500\u{00A0}KWD"),
        ("SEK", "0", "SEK\u{00A0}0.00", "0,00\u{00A0}SEK"),
        ("EUR", "0", "€0.00", "0,00\u{00A0}€"),
        ("JPY", "0", "¥0", "0\u{00A0}¥"),
        ("KWD", "0", "KWD\u{00A0}0.000", "0,000\u{00A0}KWD")
    ])
    func ordinaryCurrencyKeepsDisplay(_ sample: (code: String, value: String, english: String, russian: String)) throws {
        let amount = try decimal(sample.value)
        for (localeID, expected) in [("en_US", sample.english), ("ru_RU", sample.russian)] {
            let locale = Locale(identifier: localeID)
            let exact = try #require(OverviewFormatting.exactCurrency(amount, currencyCode: sample.code, locale: locale))
            #expect(exact == expected)
            #expect(exact == OverviewFormatting.currency(amount, currencyCode: sample.code, locale: locale))
            #expect(try valueOfLocalizedCurrency(exact, localeID: localeID) == amount)
        }
    }

    @Test("Exact currency preserves the complete original Decimal across signs and scales", arguments: [
        ("SEK", "123456789.12345678901234567890123456789"),
        ("EUR", "1.004"),
        ("EUR", "-12345678.12345678901234567890123456789"),
        ("JPY", "-0.5"),
        ("KWD", "1.0004"),
        ("KWD", "0." + String(repeating: "0", count: 123) + "12345")
    ], ["en_US", "ru_RU"])
    func exactCurrencyRoundTrips(_ sample: (code: String, value: String), _ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let amount = try decimal(sample.value)
        #expect(NSDecimalNumber(decimal: amount).stringValue == sample.value)
        let exact = try #require(OverviewFormatting.exactCurrency(amount, currencyCode: sample.code, locale: locale))
        #expect(try valueOfLocalizedCurrency(exact, localeID: localeID) == amount)
        #expect(exact != OverviewFormatting.currency(amount, currencyCode: sample.code, locale: locale))
    }

    @Test("Applied rates keep their full exact amount and existing pay unit", arguments: ["en_US", "ru_RU"])
    func rateRetainsExactAmount(_ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let amount = try decimal("12.345678901234567890123456789")
        let localized = localeID == "ru_RU" ? "12,345678901234567890123456789\u{00A0}€" : "€12.345678901234567890123456789"
        let hourly = OverviewFormatting.rate(amount: amount, basis: .hourly, currencyCode: "EUR", locale: locale)
        let fixed = OverviewFormatting.rate(amount: amount, basis: .fixedPerShift, currencyCode: "EUR", locale: locale)
        #expect(hourly == "\(localized) / \(PaycheckResultStrings.rateHour)")
        #expect(fixed == "\(localized) / \(PaycheckResultStrings.rateShift)")
    }

    @Test("NaN retains its existing localized display", arguments: [("en_US", "NaN"), ("ru_RU", "не\u{00A0}число")])
    func nanKeepsDisplay(_ sample: (localeID: String, expected: String)) {
        let locale = Locale(identifier: sample.localeID)
        #expect(OverviewFormatting.exactCurrency(.nan, currencyCode: "SEK", locale: locale) == sample.expected)
    }

    private func valueOfLocalizedCurrency(_ display: String, localeID: String) throws -> Decimal {
        // Inspect the rendered digits with Decimal's POSIX parser, independently of currency formatting.
        let separator: Character = localeID == "ru_RU" ? "," : "."
        let ascii = display.compactMap { character -> Character? in
            if character == separator { return "." }
            if character.isASCII && character.isNumber || character == "-" { return character }
            return nil
        }
        return try decimal(String(ascii))
    }

    private func decimal(_ text: String) throws -> Decimal {
        try #require(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")))
    }
}
