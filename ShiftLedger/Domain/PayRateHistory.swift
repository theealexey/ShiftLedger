import Foundation

enum PayRateHistoryValidationError: Error, Equatable {
    case missingPayRates
    case missingInitialPayRate
    case multipleInitialPayRates
    case duplicatePayRateEffectiveFrom
    case duplicatePayRateID
}

struct PayRateHistory: Equatable {
    let payRates: [PayRate]

    private let initialPayRate: PayRate

    init(payRates: [PayRate]) throws(PayRateHistoryValidationError) {
        guard payRates.isEmpty == false else {
            throw PayRateHistoryValidationError.missingPayRates
        }

        let initialPayRates = payRates.filter { $0.effectiveFrom == nil }
        guard let initialPayRate = initialPayRates.first else {
            throw PayRateHistoryValidationError.missingInitialPayRate
        }
        guard initialPayRates.count == 1 else {
            throw PayRateHistoryValidationError.multipleInitialPayRates
        }

        var datedEffectiveFroms = Set<LocalDate>()
        for payRate in payRates {
            guard let effectiveFrom = payRate.effectiveFrom else {
                continue
            }

            guard datedEffectiveFroms.insert(effectiveFrom).inserted else {
                throw PayRateHistoryValidationError.duplicatePayRateEffectiveFrom
            }
        }

        var payRateIDs = Set<UUID>()
        for payRate in payRates {
            guard payRateIDs.insert(payRate.id).inserted else {
                throw PayRateHistoryValidationError.duplicatePayRateID
            }
        }

        self.payRates = payRates.sorted(by: Self.isOrderedBefore)
        self.initialPayRate = initialPayRate
    }

    func applicablePayRate(on localDate: LocalDate) -> PayRate {
        for payRate in payRates.reversed() {
            guard let effectiveFrom = payRate.effectiveFrom else {
                continue
            }

            if effectiveFrom <= localDate {
                return payRate
            }
        }

        return initialPayRate
    }

    private static func isOrderedBefore(_ lhs: PayRate, _ rhs: PayRate) -> Bool {
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
