import Foundation

enum JobValidationError: Error, Equatable {
    case emptyName
    case invalidCurrencyCode
    case invalidTimeZoneIdentifier
    case missingPayRates
    case duplicatePayRateEffectiveFrom
}

struct Job: Equatable {
    let id: UUID
    let name: String
    let currencyCode: String
    let timeZoneIdentifier: String
    let payPeriodSchedule: PayPeriodSchedule
    let payRates: [PayRate]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        currencyCode: String,
        timeZoneIdentifier: String,
        payPeriodSchedule: PayPeriodSchedule,
        payRates: [PayRate],
        createdAt: Date = Date()
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            throw JobValidationError.emptyName
        }

        let normalizedCurrencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard Locale.Currency(normalizedCurrencyCode).isISOCurrency else {
            throw JobValidationError.invalidCurrencyCode
        }

        guard TimeZone.knownTimeZoneIdentifiers.contains(timeZoneIdentifier) else {
            throw JobValidationError.invalidTimeZoneIdentifier
        }

        guard payRates.isEmpty == false else {
            throw JobValidationError.missingPayRates
        }

        let effectiveFromDates = Set(payRates.map(\.effectiveFrom))
        guard effectiveFromDates.count == payRates.count else {
            throw JobValidationError.duplicatePayRateEffectiveFrom
        }

        self.id = id
        self.name = normalizedName
        self.currencyCode = normalizedCurrencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.payPeriodSchedule = payPeriodSchedule
        self.payRates = payRates
        self.createdAt = createdAt
    }
}
