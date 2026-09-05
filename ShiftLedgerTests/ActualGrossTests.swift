import Foundation
import Testing
@testable import ShiftLedger

struct ActualGrossTests {
    @Test("Положительная целая сумма принимается")
    func acceptsPositiveIntegerAmount() throws {
        let actualGross = try ActualGross(amount: Decimal(1_500))

        #expect(actualGross.amount == Decimal(1_500))
    }

    @Test("Нулевая сумма принимается")
    func acceptsZeroAmount() throws {
        let actualGross = try ActualGross(amount: .zero)

        #expect(actualGross.amount == .zero)
    }

    @Test("Отрицательная целая сумма отклоняется")
    func rejectsNegativeIntegerAmount() {
        #expect(throws: ActualGrossValidationError.negativeAmount) {
            try ActualGross(amount: Decimal(-1))
        }
    }

    @Test("Отрицательная дробная сумма отклоняется")
    func rejectsNegativeFractionalAmount() throws {
        let amount = try #require(
            Decimal(string: "-0.01", locale: Locale(identifier: "en_US_POSIX"))
        )

        #expect(throws: ActualGrossValidationError.negativeAmount) {
            try ActualGross(amount: amount)
        }
    }

    @Test("Положительная дробная сумма сохраняется без округления")
    func preservesPositiveFractionalAmount() throws {
        let amount = try #require(
            Decimal(string: "1234.56789", locale: Locale(identifier: "en_US_POSIX"))
        )

        let actualGross = try ActualGross(amount: amount)

        #expect(actualGross.amount == amount)
    }
}
