import Foundation

struct ShiftPayBreakdown: Equatable {
    let shift: Shift
    let basePayBasis: BasePayBasis
    let appliedPayRate: PayRate
    let paidDuration: TimeInterval
    let basePay: Decimal
}

struct ExpectedGrossBreakdown: Equatable {
    let period: PayCalculationPeriod
    let shiftBreakdowns: [ShiftPayBreakdown]
    let expectedGross: Decimal
}
