import Foundation

struct PaycheckComparison: Equatable {
    let expected: ExpectedGrossBreakdown
    let actualGross: ActualGross

    var difference: Decimal {
        actualGross.amount - expected.expectedGross
    }
}
