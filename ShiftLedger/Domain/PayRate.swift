import Foundation

enum PayRateValidationError: Error, Equatable {
    case nonPositiveAmount
}

struct PayRate: Equatable {
    let id: UUID
    let amount: Decimal
    let effectiveFrom: LocalDate?

    init(id: UUID = UUID(), amount: Decimal, effectiveFrom: LocalDate?) throws {
        guard amount > .zero else {
            throw PayRateValidationError.nonPositiveAmount
        }

        self.id = id
        self.amount = amount
        self.effectiveFrom = effectiveFrom
    }

    static func isOrderedBefore(_ lhs: PayRate, _ rhs: PayRate) -> Bool {
        switch (lhs.effectiveFrom, rhs.effectiveFrom) {
        case (nil, nil):
            return false
        case (nil, _):
            return true
        case (_, nil):
            return false
        case let (lhsDate?, rhsDate?):
            return lhsDate < rhsDate
        }
    }
}
