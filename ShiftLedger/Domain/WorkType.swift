import Foundation

struct WorkType: Equatable {
    let basePayBasis: BasePayBasis

    private let payRateHistory: PayRateHistory

    var payRates: [PayRate] {
        payRateHistory.payRates
    }

    init(basePayBasis: BasePayBasis, payRateHistory: PayRateHistory) {
        self.basePayBasis = basePayBasis
        self.payRateHistory = payRateHistory
    }

    func applicablePayRate(on localDate: LocalDate) -> PayRate {
        payRateHistory.applicablePayRate(on: localDate)
    }

    func basePay(for shift: Shift, on localDate: LocalDate) -> Decimal {
        let payRate = applicablePayRate(on: localDate)
        return basePay(for: shift, using: payRate)
    }

    func basePay(for shift: Shift, using payRate: PayRate) -> Decimal {
        switch basePayBasis {
        case .hourly:
            let paidHours = Decimal(shift.paidDuration) / Decimal(3_600)
            return payRate.amount * paidHours
        case .fixedPerShift:
            return payRate.amount
        }
    }
}
