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

enum PayRateResolutionError: Error, Equatable {
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
    case missingInitialPayRate
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

    func applicablePayRate(for shift: Shift) throws(PayRateResolutionError) -> PayRate {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PayRateResolutionError.invalidJobTimeZoneIdentifier
        }

        let localStartDate: LocalDate
        do {
            localStartDate = try LocalDate(date: shift.start, in: timeZone)
        } catch {
            throw PayRateResolutionError.localDateConversionFailed(error)
        }

        for payRate in payRates.reversed() {
            if let effectiveFrom = payRate.effectiveFrom {
                if effectiveFrom <= localStartDate {
                    return payRate
                }
            } else {
                return payRate
            }
        }

        throw PayRateResolutionError.missingInitialPayRate
    }
}
