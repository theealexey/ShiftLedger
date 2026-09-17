import Foundation

struct JobValidationContext {
    let currencyCode: String
    let timeZoneIdentifier: String
    let payRates: [PayRate]
}

class JobValidationHandler {
    private let next: JobValidationHandler?

    init(next: JobValidationHandler? = nil) {
        self.next = next
    }

    final func validate(_ context: JobValidationContext) throws(JobValidationError) {
        try validateCurrent(context)

        if let next {
            try next.validate(context)
        }
    }

    func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {}
}

final class CurrencyValidationHandler: JobValidationHandler {
    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        guard Locale.Currency(context.currencyCode).isISOCurrency else {
            throw JobValidationError.invalidCurrencyCode
        }
    }
}

final class TimeZoneValidationHandler: JobValidationHandler {
    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        guard TimeZone.knownTimeZoneIdentifiers.contains(context.timeZoneIdentifier) else {
            throw JobValidationError.invalidTimeZoneIdentifier
        }
    }
}

final class PayRatesValidationHandler: JobValidationHandler {
    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        _ = try Self.makePayRateHistory(from: context.payRates)
    }

    static func makePayRateHistory(
        from payRates: [PayRate]
    ) throws(JobValidationError) -> PayRateHistory {
        do {
            return try PayRateHistory(payRates: payRates)
        } catch {
            switch error {
            case .missingPayRates:
                throw JobValidationError.missingPayRates
            case .missingInitialPayRate:
                throw JobValidationError.missingInitialPayRate
            case .multipleInitialPayRates:
                throw JobValidationError.multipleInitialPayRates
            case .duplicatePayRateEffectiveFrom:
                throw JobValidationError.duplicatePayRateEffectiveFrom
            case .duplicatePayRateID:
                throw JobValidationError.duplicatePayRateID
            }
        }
    }
}

struct JobValidationChain {
    private let firstHandler: JobValidationHandler

    init() {
        let payRatesHandler = PayRatesValidationHandler()
        let timeZoneHandler = TimeZoneValidationHandler(next: payRatesHandler)
        firstHandler = CurrencyValidationHandler(next: timeZoneHandler)
    }

    func validate(_ context: JobValidationContext) throws(JobValidationError) {
        try firstHandler.validate(context)
    }
}
