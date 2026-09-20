import Foundation

struct JobValidationContext {
    let currencyCode: String
    let timeZoneIdentifier: String
    let workTypes: [WorkType]
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

final class WorkTypesValidationHandler: JobValidationHandler {
    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        try Self.validate(context.workTypes)
    }

    static func validate(_ workTypes: [WorkType]) throws(JobValidationError) {
        guard workTypes.isEmpty == false else {
            throw JobValidationError.missingWorkTypes
        }

        var workTypeIDs = Set<UUID>()
        for workType in workTypes {
            guard workTypeIDs.insert(workType.id).inserted else {
                throw JobValidationError.duplicateWorkTypeID
            }
        }
    }
}

struct JobValidationChain {
    private let firstHandler: JobValidationHandler

    init() {
        let workTypesHandler = WorkTypesValidationHandler()
        let timeZoneHandler = TimeZoneValidationHandler(next: workTypesHandler)
        firstHandler = CurrencyValidationHandler(next: timeZoneHandler)
    }

    func validate(_ context: JobValidationContext) throws(JobValidationError) {
        try firstHandler.validate(context)
    }
}
