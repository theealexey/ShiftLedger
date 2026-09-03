import Foundation
import Testing
@testable import ShiftLedger

struct JobValidationChainTests {
    @Test("Невалидная валюта отклоняется, валидная передаётся дальше")
    func currencyHandlerValidatesAndForwards() throws {
        let recorder = RecordingValidationHandler()
        let handler = CurrencyValidationHandler(next: recorder)
        let validContext = try makeContext(currencyCode: "EUR")

        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try handler.validate(try makeContext(currencyCode: "EURO"))
        }
        #expect(recorder.didValidate == false)

        try handler.validate(validContext)
        #expect(recorder.didValidate)
    }

    @Test("Невалидная часовая зона отклоняется, валидная передаётся дальше")
    func timeZoneHandlerValidatesAndForwards() throws {
        let recorder = RecordingValidationHandler()
        let handler = TimeZoneValidationHandler(next: recorder)

        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try handler.validate(try makeContext(timeZoneIdentifier: "GMT+2"))
        }
        #expect(recorder.didValidate == false)

        try handler.validate(try makeContext())
        #expect(recorder.didValidate)
    }

    @Test("Обработчик ставок сохраняет порядок валидации")
    func payRatesHandlerPreservesFailFastOrder() throws {
        let initialID = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        let datedRateID = UUID(uuid: (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17))
        let duplicateEffectiveFromID = UUID(uuid: (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18))
        let duplicateEffectiveFromAgainID = UUID(uuid: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19))
        let secondInitialID = UUID(uuid: (5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20))
        let initialRate = try PayRate(id: initialID, amount: 100, effectiveFrom: nil)
        let secondInitialRate = try PayRate(id: secondInitialID, amount: 110, effectiveFrom: nil)
        let datedDate = try LocalDate(year: 2026, month: 10, day: 1)
        let datedRate = try PayRate(id: datedRateID, amount: 120, effectiveFrom: datedDate)
        let duplicateEffectiveFrom = try PayRate(id: duplicateEffectiveFromID, amount: 130, effectiveFrom: datedDate)
        let duplicateEffectiveFromAgain = try PayRate(id: duplicateEffectiveFromAgainID, amount: 140, effectiveFrom: datedDate)
        let duplicateIDRate = try PayRate(
            id: initialID,
            amount: 150,
            effectiveFrom: try LocalDate(year: 2026, month: 11, day: 1)
        )
        let recorder = RecordingValidationHandler()
        let handler = PayRatesValidationHandler(next: recorder)

        #expect(throws: JobValidationError.missingPayRates) {
            try handler.validate(try makeContext(payRates: []))
        }
        #expect(throws: JobValidationError.missingInitialPayRate) {
            try handler.validate(try makeContext(payRates: [datedRate]))
        }
        #expect(throws: JobValidationError.multipleInitialPayRates) {
            try handler.validate(try makeContext(payRates: [initialRate, secondInitialRate]))
        }
        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try handler.validate(try makeContext(payRates: [initialRate, duplicateEffectiveFrom, duplicateEffectiveFromAgain]))
        }
        #expect(recorder.didValidate == false)

        #expect(throws: JobValidationError.duplicatePayRateID) {
            try handler.validate(try makeContext(payRates: [initialRate, duplicateIDRate]))
        }

        try handler.validate(try makeContext(payRates: [initialRate, datedRate]))
        #expect(recorder.didValidate)
    }

    @Test("Несколько initial ставок имеют приоритет над повторяющимся идентификатором")
    func multipleInitialRatesTakePrecedenceOverDuplicateID() throws {
        let duplicateID = UUID(uuid: (6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21))
        let first = try PayRate(id: duplicateID, amount: 100, effectiveFrom: nil)
        let second = try PayRate(id: duplicateID, amount: 110, effectiveFrom: nil)

        #expect(throws: JobValidationError.multipleInitialPayRates) {
            try PayRatesValidationHandler().validate(
                try makeContext(payRates: [first, second])
            )
        }
    }

    @Test("Полная цепочка сохраняет порядок ошибок")
    func fullChainPreservesCrossHandlerPrecedence() throws {
        let chain = JobValidationChain()

        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try chain.validate(try makeContext(currencyCode: "EURO", timeZoneIdentifier: "GMT+2", payRates: []))
        }
        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try chain.validate(try makeContext(timeZoneIdentifier: "GMT+2", payRates: []))
        }
        #expect(throws: JobValidationError.missingPayRates) {
            try chain.validate(try makeContext(payRates: []))
        }
    }

    @Test("Валюта нормализуется перед валидацией и сохранением")
    func currencyNormalizationIsPreserved() throws {
        let job = try Job(
            currencyCode: " eur ",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [try PayRate(amount: 100, effectiveFrom: nil)]
        )

        #expect(job.currencyCode == "EUR")
    }

    @Test("Job сохраняет каноническую сортировку ставок")
    func jobPayRateSortingIsPreserved() throws {
        let initialRate = try PayRate(amount: 100, effectiveFrom: nil)
        let laterRate = try PayRate(
            amount: 120,
            effectiveFrom: try LocalDate(year: 2026, month: 11, day: 1)
        )
        let earlierRate = try PayRate(
            amount: 110,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )

        let job = try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [laterRate, initialRate, earlierRate]
        )

        #expect(job.payRates == [initialRate, earlierRate, laterRate])
    }

    @Test("Проверка идентификаторов ставок выполняется после дат вступления в силу")
    func duplicateIDIsCheckedAfterEffectiveFrom() throws {
        let duplicateID = UUID(uuid: (9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6))
        let initialRate = try PayRate(id: duplicateID, amount: 100, effectiveFrom: nil)
        let effectiveFrom = try LocalDate(year: 2026, month: 12, day: 1)
        let firstDatedRate = try PayRate(id: duplicateID, amount: 120, effectiveFrom: effectiveFrom)
        let secondDatedRate = try PayRate(id: duplicateID, amount: 130, effectiveFrom: effectiveFrom)

        #expect(throws: JobValidationError.duplicatePayRateEffectiveFrom) {
            try Job(
                currencyCode: "EUR",
                timeZoneIdentifier: "Europe/Stockholm",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: [initialRate, firstDatedRate, secondDatedRate]
            )
        }
    }

    private func makeContext(
        currencyCode: String = "EUR",
        timeZoneIdentifier: String = "Europe/Stockholm",
        payRates: [PayRate]? = nil
    ) throws -> JobValidationContext {
        let resolvedPayRates: [PayRate]
        if let payRates {
            resolvedPayRates = payRates
        } else {
            resolvedPayRates = [try PayRate(amount: 100, effectiveFrom: nil)]
        }
            return JobValidationContext(
                currencyCode: currencyCode,
                timeZoneIdentifier: timeZoneIdentifier,
                payRates: resolvedPayRates
            )
    }
}

private final class RecordingValidationHandler: JobValidationHandler {
    private(set) var didValidate = false

    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        didValidate = true
    }
}
