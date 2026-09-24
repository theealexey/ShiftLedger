import Foundation

enum WorkTypeNameValidationError: Error, Equatable {
    case empty
}

struct WorkType: Equatable {
    let id: UUID
    let name: String?
    let basePayBasis: BasePayBasis

    private let payRateHistory: PayRateHistory

    var payRates: [PayRate] {
        payRateHistory.payRates
    }

    init(
        id: UUID,
        name: String? = nil,
        basePayBasis: BasePayBasis,
        payRateHistory: PayRateHistory
    ) {
        self.id = id
        self.name = name
        self.basePayBasis = basePayBasis
        self.payRateHistory = payRateHistory
    }

    func applicablePayRate(on localDate: LocalDate) -> PayRate {
        payRateHistory.applicablePayRate(on: localDate)
    }

    func renamed(to rawName: String) throws(WorkTypeNameValidationError) -> WorkType {
        let normalizedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            throw .empty
        }

        return WorkType(
            id: id,
            name: normalizedName,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory
        )
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
