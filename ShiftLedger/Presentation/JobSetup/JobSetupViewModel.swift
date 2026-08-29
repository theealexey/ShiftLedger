import Foundation

@MainActor
final class JobSetupViewModel {
    private(set) var draft: JobSetupDraft

    init(initialCurrencyCode: String, initialTimeZoneIdentifier: String) {
        draft = JobSetupDraft(
            name: "",
            currencyCode: initialCurrencyCode,
            timeZoneIdentifier: initialTimeZoneIdentifier
        )
    }

    var canContinue: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func updateName(_ value: String) {
        draft.name = value
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
