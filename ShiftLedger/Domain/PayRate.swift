import Foundation

enum PayRateValidationError: Error, Equatable {
    case negativeAmount
}

struct PayRate: Equatable {
    let id: UUID
    let amount: Decimal
    let effectiveFrom: LocalDate

    init(id: UUID = UUID(), amount: Decimal, effectiveFrom: LocalDate) throws {
        guard amount >= .zero else {
            throw PayRateValidationError.negativeAmount
        }

        self.id = id
        self.amount = amount
        self.effectiveFrom = effectiveFrom
    }
}
