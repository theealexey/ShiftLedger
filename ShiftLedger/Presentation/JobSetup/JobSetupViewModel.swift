import Foundation

@MainActor
final class JobSetupViewModel {
    private(set) var draft: JobSetupDraft
    private let decimalInputLocale: Locale

    init(
        initialCurrencyCode: String,
        initialTimeZoneIdentifier: String,
        decimalInputLocale: Locale = .current
    ) {
        draft = JobSetupDraft(
            name: "",
            hourlyRateText: "",
            currencyCode: initialCurrencyCode,
            timeZoneIdentifier: initialTimeZoneIdentifier
        )
        self.decimalInputLocale = decimalInputLocale
    }

    var canContinue: Bool {
        hourlyRate.map { $0 > .zero } ?? false
    }

    var hasValidName: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hourlyRate: Decimal? {
        let text = draft.hourlyRateText
        let decimalSeparator = decimalInputLocale.decimalSeparator ?? "."
        let components = text.components(separatedBy: decimalSeparator)

        guard
            components.count <= 2,
            components.allSatisfy({
                $0.isEmpty == false && $0.allSatisfy(\.isWholeNumber)
            }),
            let amount = Decimal(string: text, locale: decimalInputLocale)
        else {
            return nil
        }

        return amount
    }

    func updateName(_ value: String) {
        draft.name = value
    }

    func updateHourlyRateText(_ value: String) {
        draft.hourlyRateText = value
    }

    func selectCurrency(code: String) -> Bool {
        guard Locale.Currency(code).isISOCurrency else {
            return false
        }

        draft.currencyCode = code
        return true
    }

    func selectTimeZone(identifier: String) -> Bool {
        guard TimeZone.knownTimeZoneIdentifiers.contains(identifier) else {
            return false
        }

        draft.timeZoneIdentifier = identifier
        return true
    }
}
