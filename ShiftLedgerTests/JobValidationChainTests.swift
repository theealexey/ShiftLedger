import Foundation
import Testing
@testable import ShiftLedger

struct JobValidationChainTests {
    @Test("Невалидная валюта отклоняется, валидная передаётся дальше")
    func currencyHandlerValidatesAndForwards() throws {
        let recorder = RecordingValidationHandler()
        let handler = CurrencyValidationHandler(next: recorder)

        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try handler.validate(try makeContext(currencyCode: "EURO"))
        }
        #expect(recorder.didValidate == false)

        try handler.validate(try makeContext())
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

    @Test("WorkType handler проверяет cardinality и identity")
    func workTypesHandlerValidatesCollection() throws {
        let recorder = RecordingValidationHandler()
        let handler = WorkTypesValidationHandler(next: recorder)
        let workType = try makeWorkType(id: deterministicID(1))
        let duplicate = try makeWorkType(
            id: workType.id,
            basis: .fixedPerShift,
            amount: 500
        )

        #expect(throws: JobValidationError.missingWorkTypes) {
            try handler.validate(try makeContext(workTypes: []))
        }
        #expect(throws: JobValidationError.duplicateWorkTypeID) {
            try handler.validate(try makeContext(workTypes: [workType, duplicate]))
        }
        #expect(recorder.didValidate == false)

        try handler.validate(try makeContext(workTypes: [workType]))
        #expect(recorder.didValidate)
    }

    @Test("Полная цепочка сохраняет metadata → WorkType precedence")
    func fullChainPreservesCrossHandlerPrecedence() throws {
        let chain = JobValidationChain()

        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try chain.validate(
                try makeContext(
                    currencyCode: "EURO",
                    timeZoneIdentifier: "GMT+2",
                    workTypes: []
                )
            )
        }
        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try chain.validate(
                try makeContext(timeZoneIdentifier: "GMT+2", workTypes: [])
            )
        }
        #expect(throws: JobValidationError.missingWorkTypes) {
            try chain.validate(try makeContext(workTypes: []))
        }
    }

    @Test("Валюта нормализуется перед валидацией и сохранением")
    func currencyNormalizationIsPreserved() throws {
        let job = try Job(
            currencyCode: " eur ",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [try makeWorkType(id: deterministicID(1))]
        )

        #expect(job.currencyCode == "EUR")
    }

    @Test("Legacy initializer сохраняет каноническую сортировку ставок")
    func legacyInitializerPreservesPayRateSorting() throws {
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
        let workType = try #require(job.soleWorkType)

        #expect(workType.payRates == [initialRate, earlierRate, laterRate])
    }

    @Test("Legacy rate validation сохраняет порядок effective date перед ID")
    func legacyRateValidationPreservesPrecedence() throws {
        let duplicateID = deterministicID(9)
        let initialRate = try PayRate(id: duplicateID, amount: 100, effectiveFrom: nil)
        let effectiveFrom = try LocalDate(year: 2026, month: 12, day: 1)
        let firstDatedRate = try PayRate(
            id: duplicateID,
            amount: 120,
            effectiveFrom: effectiveFrom
        )
        let secondDatedRate = try PayRate(
            id: duplicateID,
            amount: 130,
            effectiveFrom: effectiveFrom
        )

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

    @Test("Legacy initializer проверяет metadata до PayRateHistory")
    func legacyInitializerPreservesMetadataValidationPrecedence() {
        #expect(throws: JobValidationError.invalidCurrencyCode) {
            try Job(
                currencyCode: "EURO",
                timeZoneIdentifier: "GMT+2",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: []
            )
        }
        #expect(throws: JobValidationError.invalidTimeZoneIdentifier) {
            try Job(
                currencyCode: "EUR",
                timeZoneIdentifier: "GMT+2",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: []
            )
        }
    }

    private func makeContext(
        currencyCode: String = "EUR",
        timeZoneIdentifier: String = "Europe/Stockholm",
        workTypes: [WorkType]? = nil
    ) throws -> JobValidationContext {
        JobValidationContext(
            currencyCode: currencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: try workTypes ?? [makeWorkType(id: deterministicID(1))]
        )
    }

    private func makeWorkType(
        id: UUID,
        basis: BasePayBasis = .hourly,
        amount: Decimal = 100
    ) throws -> WorkType {
        WorkType(
            id: id,
            basePayBasis: basis,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(amount: amount, effectiveFrom: nil)]
            )
        )
    }

    private func deterministicID(_ byte: UInt8) -> UUID {
        UUID(uuid: (
            byte, byte, byte, byte,
            byte, byte, byte, byte,
            byte, byte, byte, byte,
            byte, byte, byte, byte
        ))
    }
}

private final class RecordingValidationHandler: JobValidationHandler {
    private(set) var didValidate = false

    override func validateCurrent(_ context: JobValidationContext) throws(JobValidationError) {
        didValidate = true
    }
}
