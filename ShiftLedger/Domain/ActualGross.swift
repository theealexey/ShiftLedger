import Foundation

enum ActualGrossValidationError: Error, Equatable {
    case negativeAmount
}

struct ActualGross: Equatable {
    let amount: Decimal

    init(amount: Decimal) throws(ActualGrossValidationError) {
        guard amount >= .zero else {
            throw ActualGrossValidationError.negativeAmount
        }

        self.amount = amount
    }
}
