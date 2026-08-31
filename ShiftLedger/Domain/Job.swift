import Foundation

enum JobValidationError: Error, Equatable {
    case invalidCurrencyCode
    case invalidTimeZoneIdentifier
    case missingPayRates
    case missingInitialPayRate
    case multipleInitialPayRates
    case duplicatePayRateEffectiveFrom
    case duplicatePayRateID
}

struct Job: Equatable {
    let id: UUID
    let currencyCode: String
    let timeZoneIdentifier: String
    let basePayBasis: BasePayBasis
    let payCalculationCycle: PayCalculationCycle
    let payRates: [PayRate]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        basePayBasis: BasePayBasis,
        payCalculationCycle: PayCalculationCycle,
        payRates: [PayRate],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
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

        let initialPayRateCount = payRates.count { $0.effectiveFrom == nil }
        guard initialPayRateCount > 0 else {
            throw JobValidationError.missingInitialPayRate
        }
        guard initialPayRateCount == 1 else {
            throw JobValidationError.multipleInitialPayRates
        }

        var datedEffectiveFroms = Set<LocalDate>()
        for payRate in payRates {
            guard let effectiveFrom = payRate.effectiveFrom else {
                continue
            }

            guard datedEffectiveFroms.insert(effectiveFrom).inserted else {
                throw JobValidationError.duplicatePayRateEffectiveFrom
            }
        }

        var payRateIDs = Set<UUID>()
        for payRate in payRates {
            guard payRateIDs.insert(payRate.id).inserted else {
                throw JobValidationError.duplicatePayRateID
            }
        }

        self.id = id
        self.currencyCode = normalizedCurrencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.basePayBasis = basePayBasis
        self.payCalculationCycle = payCalculationCycle
        self.payRates = payRates.sorted(by: PayRate.isOrderedBefore)
        self.createdAt = createdAt
    }
}
