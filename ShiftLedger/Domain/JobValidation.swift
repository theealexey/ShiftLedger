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
        guard context.payRates.isEmpty == false else {
            throw JobValidationError.missingPayRates
        }

        let initialPayRateCount = context.payRates.count { $0.effectiveFrom == nil }
        guard initialPayRateCount > 0 else {
            throw JobValidationError.missingInitialPayRate
        }
        guard initialPayRateCount == 1 else {
            throw JobValidationError.multipleInitialPayRates
        }

        var datedEffectiveFroms = Set<LocalDate>()
        for payRate in context.payRates {
            guard let effectiveFrom = payRate.effectiveFrom else {
                continue
            }

            guard datedEffectiveFroms.insert(effectiveFrom).inserted else {
                throw JobValidationError.duplicatePayRateEffectiveFrom
            }
        }

        var payRateIDs = Set<UUID>()
        for payRate in context.payRates {
            guard payRateIDs.insert(payRate.id).inserted else {
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
