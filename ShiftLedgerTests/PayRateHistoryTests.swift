import Foundation
import Testing
@testable import ShiftLedger

struct PayRateHistoryTests {
    @Test("Пустая история ставок отклоняется")
    func rejectsEmptyHistory() {
        #expect(throws: PayRateHistoryValidationError.missingPayRates) {
            try PayRateHistory(payRates: [])
        }
    }

    @Test("История без initial ставки отклоняется")
    func rejectsMissingInitialRate() throws {
        let datedRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try localDate(month: 9, day: 1)
        )

        #expect(throws: PayRateHistoryValidationError.missingInitialPayRate) {
            try PayRateHistory(payRates: [datedRate])
        }
    }

    @Test("Несколько initial ставок отклоняются")
    func rejectsMultipleInitialRates() throws {
        let first = try PayRate(amount: 1_000, effectiveFrom: nil)
        let second = try PayRate(amount: 1_200, effectiveFrom: nil)

        #expect(throws: PayRateHistoryValidationError.multipleInitialPayRates) {
            try PayRateHistory(payRates: [first, second])
        }
    }

    @Test("Повторяющийся идентификатор ставки отклоняется")
    func rejectsDuplicateRateID() throws {
        let id = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        let initialRate = try PayRate(id: id, amount: 1_000, effectiveFrom: nil)
        let datedRate = try PayRate(
            id: id,
            amount: 1_200,
            effectiveFrom: try localDate(month: 9, day: 1)
        )

        #expect(throws: PayRateHistoryValidationError.duplicatePayRateID) {
            try PayRateHistory(payRates: [initialRate, datedRate])
        }
    }

    @Test("Повторяющаяся дата начала ставки отклоняется")
    func rejectsDuplicateEffectiveFrom() throws {
        let effectiveFrom = try localDate(month: 9, day: 1)
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let firstDatedRate = try PayRate(amount: 1_200, effectiveFrom: effectiveFrom)
        let secondDatedRate = try PayRate(amount: 1_500, effectiveFrom: effectiveFrom)

        #expect(throws: PayRateHistoryValidationError.duplicatePayRateEffectiveFrom) {
            try PayRateHistory(payRates: [initialRate, firstDatedRate, secondDatedRate])
        }
    }

    @Test("История нормализует ставки в детерминированный хронологический порядок")
    func normalizesRatesChronologically() throws {
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try localDate(month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 1_500,
            effectiveFrom: try localDate(month: 10, day: 1)
        )

        let history = try PayRateHistory(
            payRates: [octoberRate, initialRate, septemberRate]
        )

        #expect(history.payRates == [initialRate, septemberRate, octoberRate])
    }

    @Test("Adding a dated rate is immutable and chronologically normalized")
    func addingDatedRate() throws {
        let initial = try PayRate(amount: 100, effectiveFrom: nil)
        let october = try PayRate(amount: 150, effectiveFrom: localDate(month: 10, day: 1))
        let september = try PayRate(amount: 125, effectiveFrom: localDate(month: 9, day: 1))
        let original = try PayRateHistory(payRates: [initial, october])

        let updated = try original.adding(september)

        #expect(original.payRates == [initial, october])
        #expect(updated.payRates == [initial, september, october])
    }

    @Test("Adding a duplicate effective date is rejected without changing history")
    func addingDuplicateDate() throws {
        let initial = try PayRate(amount: 100, effectiveFrom: nil)
        let dated = try PayRate(amount: 125, effectiveFrom: localDate(month: 9, day: 1))
        let history = try PayRateHistory(payRates: [initial, dated])
        let duplicate = try PayRate(amount: 150, effectiveFrom: localDate(month: 9, day: 1))

        #expect(throws: PayRateHistoryValidationError.duplicatePayRateEffectiveFrom) {
            try history.adding(duplicate)
        }
        #expect(history.payRates == [initial, dated])
    }

    @Test("Adding a duplicate rate ID is rejected without changing history")
    func addingDuplicateID() throws {
        let id = UUID(uuid: (7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let initial = try PayRate(id: id, amount: 100, effectiveFrom: nil)
        let history = try PayRateHistory(payRates: [initial])
        let duplicate = try PayRate(id: id, amount: 125, effectiveFrom: localDate(month: 9, day: 1))

        #expect(throws: PayRateHistoryValidationError.duplicatePayRateID) {
            try history.adding(duplicate)
        }
        #expect(history.payRates == [initial])
    }

    @Test(
        "История разрешает применимую ставку на исторических границах",
        arguments: [
            (month: 8, day: 31, expectedAmount: Decimal(1_000)),
            (month: 9, day: 1, expectedAmount: Decimal(1_200)),
            (month: 9, day: 30, expectedAmount: Decimal(1_200)),
            (month: 10, day: 1, expectedAmount: Decimal(1_500)),
            (month: 1, day: 1, expectedAmount: Decimal(1_500))
        ]
    )
    func resolvesApplicableRate(
        month: Int,
        day: Int,
        expectedAmount: Decimal
    ) throws {
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let septemberRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try localDate(month: 9, day: 1)
        )
        let octoberRate = try PayRate(
            amount: 1_500,
            effectiveFrom: try localDate(month: 10, day: 1)
        )
        let history = try PayRateHistory(
            payRates: [septemberRate, octoberRate, initialRate]
        )
        let year = month == 1 ? 2027 : 2026

        let result = history.applicablePayRate(
            on: try LocalDate(year: year, month: month, day: day)
        )

        #expect(result.amount == expectedAmount)
    }

    private func localDate(month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: 2026, month: month, day: day)
    }
}
