import Foundation

enum WorkTypeNameValidationError: Error, Equatable {
    case empty
}

enum WorkTypePayRateChangeError: Error, Equatable {
    case initialPayRateNotAllowed
    case invalidHistory(PayRateHistoryValidationError)
}

enum WorkTypeArchiveError: Error, Equatable {
    case alreadyArchived
}

struct WorkType: Equatable {
    let id: UUID
    let name: String?
    let basePayBasis: BasePayBasis
    let isArchived: Bool

    private let payRateHistory: PayRateHistory

    var payRates: [PayRate] {
        payRateHistory.payRates
    }

    init(
        id: UUID,
        name: String? = nil,
        basePayBasis: BasePayBasis,
        payRateHistory: PayRateHistory,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.basePayBasis = basePayBasis
        self.payRateHistory = payRateHistory
        self.isArchived = isArchived
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
            payRateHistory: payRateHistory,
            isArchived: isArchived
        )
    }

    func addingPayRate(_ payRate: PayRate) throws(WorkTypePayRateChangeError) -> WorkType {
        guard payRate.effectiveFrom != nil else {
            throw .initialPayRateNotAllowed
        }

        let updatedHistory: PayRateHistory
        do {
            updatedHistory = try payRateHistory.adding(payRate)
        } catch {
            throw .invalidHistory(error)
        }

        return WorkType(
            id: id,
            name: name,
            basePayBasis: basePayBasis,
            payRateHistory: updatedHistory,
            isArchived: isArchived
        )
    }

    func archived() throws(WorkTypeArchiveError) -> WorkType {
        guard isArchived == false else {
            throw .alreadyArchived
        }

        return WorkType(
            id: id,
            name: name,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory,
            isArchived: true
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
