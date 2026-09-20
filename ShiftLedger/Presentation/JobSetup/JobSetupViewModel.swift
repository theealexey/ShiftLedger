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
        normalizedWorkTypeName != nil
            && basePayBasis != nil
            && (basePayAmount.map { $0 > .zero } ?? false)
    }

    var normalizedWorkTypeName: String? {
        Self.normalizeWorkTypeName(draft.workTypeNameText)
    }

    var basePayBasis: BasePayBasis? {
        draft.basePayBasis
    }

    var basePayAmount: Decimal? {
        Self.parseDecimal(draft.basePayAmountText, locale: decimalInputLocale)
    }

    static func parseDecimal(_ text: String, locale: Locale) -> Decimal? {
        WorkTypeInputParser.decimalAmount(text, locale: locale)
    }

    static func normalizeWorkTypeName(_ text: String) -> String? {
        WorkTypeInputParser.normalizedName(text)
    }

    func updateWorkTypeNameText(_ value: String) {
        draft.workTypeNameText = value
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
