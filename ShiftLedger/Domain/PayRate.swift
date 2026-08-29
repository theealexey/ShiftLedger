import Foundation

enum PayRateValidationError: Error, Equatable {
    case nonPositiveAmount
}

struct PayRate: Equatable {
    let id: UUID
    let amount: Decimal
    let effectiveFrom: LocalDate

    init(id: UUID = UUID(), amount: Decimal, effectiveFrom: LocalDate) throws {
        guard amount > .zero else {
            throw PayRateValidationError.nonPositiveAmount
        }

        self.id = id
        self.amount = amount
        self.effectiveFrom = effectiveFrom
    }
}
