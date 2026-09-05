import Foundation

enum JobValidationError: Error, Equatable {
    case invalidCurrencyCode
    case invalidTimeZoneIdentifier
    case missingPayRates
    case missingInitialPayRate
    case multipleInitialPayRates
    case duplicatePayRateEffectiveFrom
    case duplicatePayRateID
}

enum PayRateResolutionError: Error, Equatable {
    case invalidJobTimeZoneIdentifier
    case localDateConversionFailed(LocalDateConversionError)
    case missingInitialPayRate
}

enum ExpectedGrossCalculationError: Error, Equatable {
    case membershipFailed(ShiftMembershipError)
    case basePayFailed(PayRateResolutionError)
}

struct Job: Equatable {
    let id: UUID
    let currencyCode: String
    let timeZoneIdentifier: String
    let basePayBasis: BasePayBasis
    let payCalculationCycle: PayCalculationCycle
    let payRates: [PayRate]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        currencyCode: String,
        timeZoneIdentifier: String,
        basePayBasis: BasePayBasis,
        payCalculationCycle: PayCalculationCycle,
        payRates: [PayRate],
        createdAt: Date = Date()
    ) throws(JobValidationError) {
        let normalizedCurrencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let validationContext = JobValidationContext(
            currencyCode: normalizedCurrencyCode,
            timeZoneIdentifier: timeZoneIdentifier,
            payRates: payRates
        )
        try JobValidationChain().validate(validationContext)

        self.id = id
        self.currencyCode = validationContext.currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.basePayBasis = basePayBasis
        self.payCalculationCycle = payCalculationCycle
        self.payRates = payRates.sorted(by: PayRate.isOrderedBefore)
        self.createdAt = createdAt
    }

    func applicablePayRate(for shift: Shift) throws(PayRateResolutionError) -> PayRate {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw PayRateResolutionError.invalidJobTimeZoneIdentifier
        }

        let localStartDate: LocalDate
        do {
            localStartDate = try LocalDate(date: shift.start, in: timeZone)
        } catch {
            throw PayRateResolutionError.localDateConversionFailed(error)
        }

        for payRate in payRates.reversed() {
            if let effectiveFrom = payRate.effectiveFrom {
                if effectiveFrom <= localStartDate {
                    return payRate
                }
            } else {
                return payRate
            }
        }

        throw PayRateResolutionError.missingInitialPayRate
    }

    func basePay(for shift: Shift) throws(PayRateResolutionError) -> Decimal {
        let payRate = try applicablePayRate(for: shift)
        return basePayAmount(for: shift, using: payRate)
    }

    func payCalculationPeriod(
        for shift: Shift
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod {
        switch payCalculationCycle {
        case .perShift:
            return .perShift(shiftID: shift.id)
        case let .scheduled(schedule):
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                throw PayCalculationPeriodResolutionError.invalidJobTimeZoneIdentifier
            }

            let localStartDate: LocalDate
            do {
                localStartDate = try LocalDate(date: shift.start, in: timeZone)
            } catch {
                throw PayCalculationPeriodResolutionError.localDateConversionFailed(error)
            }

            do {
                return .scheduled(try schedule.period(containing: localStartDate))
            } catch {
                throw PayCalculationPeriodResolutionError.scheduledPeriodResolutionFailed
            }
        }
    }

    func contains(
        _ shift: Shift,
        in period: PayCalculationPeriod
    ) throws(ShiftMembershipError) -> Bool {
        switch period {
        case let .perShift(shiftID):
            return shift.id == shiftID
        case let .scheduled(payPeriod):
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                throw ShiftMembershipError.invalidJobTimeZoneIdentifier
            }

            let localStartDate: LocalDate
            do {
                localStartDate = try LocalDate(date: shift.start, in: timeZone)
            } catch {
                throw ShiftMembershipError.localDateConversionFailed(error)
            }

            return localStartDate >= payPeriod.start
                && localStartDate < payPeriod.endExclusive
        }
    }

    func expectedGross(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> Decimal {
        try expectedGrossBreakdown(for: period, from: shifts).expectedGross
    }

    func expectedGrossBreakdown(
        for period: PayCalculationPeriod,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> ExpectedGrossBreakdown {
        let orderedShifts = shifts.sorted(by: Self.isShiftOrderedBefore)

        var breakdowns: [ShiftPayBreakdown] = []
        var total = Decimal.zero
        for shift in orderedShifts {
            let belongsToPeriod: Bool
            do {
                belongsToPeriod = try contains(shift, in: period)
            } catch {
                throw ExpectedGrossCalculationError.membershipFailed(error)
            }

            guard belongsToPeriod else {
                continue
            }

            do {
                let breakdown = try shiftPayBreakdown(for: shift)
                breakdowns.append(breakdown)
                total += breakdown.basePay
            } catch {
                throw ExpectedGrossCalculationError.basePayFailed(error)
            }
        }

        return ExpectedGrossBreakdown(
            period: period,
            shiftBreakdowns: breakdowns,
            expectedGross: total
        )
    }

    private func basePayAmount(for shift: Shift, using payRate: PayRate) -> Decimal {
        switch basePayBasis {
        case .hourly:
            let paidHours = Decimal(shift.paidDuration) / Decimal(3_600)
            return payRate.amount * paidHours
        case .fixedPerShift:
            return payRate.amount
        }
    }

    private func shiftPayBreakdown(for shift: Shift) throws(PayRateResolutionError) -> ShiftPayBreakdown {
        let payRate = try applicablePayRate(for: shift)
        let amount = basePayAmount(for: shift, using: payRate)

        return ShiftPayBreakdown(
            shift: shift,
            basePayBasis: basePayBasis,
            appliedPayRate: payRate,
            paidDuration: shift.paidDuration,
            basePay: amount
        )
    }

    private static func isShiftOrderedBefore(_ lhs: Shift, _ rhs: Shift) -> Bool {
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        if lhs.end != rhs.end {
            return lhs.end < rhs.end
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
