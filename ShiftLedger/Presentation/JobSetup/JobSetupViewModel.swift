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
            basePayAmountText: "",
            currencyCode: initialCurrencyCode,
            timeZoneIdentifier: initialTimeZoneIdentifier,
            basePayBasis: nil,
            payCalculationCycleKind: nil,
            payPeriodAnchorDate: nil
        )
        self.decimalInputLocale = decimalInputLocale
    }

    var canContinue: Bool {
        basePayBasis != nil && (basePayAmount.map { $0 > .zero } ?? false)
    }

    var basePayBasis: BasePayBasis? {
        draft.basePayBasis
    }

    var basePayAmount: Decimal? {
        let text = draft.basePayAmountText
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

    func updateBasePayAmountText(_ value: String) {
        draft.basePayAmountText = value
    }

    func selectBasePayBasis(_ basis: BasePayBasis) {
        guard draft.basePayBasis != basis else {
            return
        }

        draft.basePayBasis = basis
        draft.basePayAmountText = ""
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
