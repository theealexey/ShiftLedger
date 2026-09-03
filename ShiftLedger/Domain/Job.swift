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
        let validationContext = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            payRates: payRates
        )
        try JobValidationChain().validate(validationContext)

        self.id = id
        self.currencyCode = validationContext.currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.basePayBasis = basePayBasis
        self.payCalculationCycle = payCalculationCycle
        self.payRates = payRates.sorted(by: PayRate.isOrderedBefore)
        self.createdAt = createdAt
    }
}
