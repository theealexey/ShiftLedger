import Foundation

struct JobPayrollCalculator {
    private let job: Job

    private struct ShiftCalculationContext {
        let workType: WorkType
        let applicablePayRate: PayRate
    }

    init(job: Job) {
        self.job = job
    }

    func applicablePayRate(for shift: Shift) throws(PayRateResolutionError) -> PayRate {
        try calculationContext(for: shift).applicablePayRate
    }

    func basePay(for shift: Shift) throws(PayRateResolutionError) -> Decimal {
        let context = try calculationContext(for: shift)
        return context.workType.basePay(for: shift, using: context.applicablePayRate)
    }

    func shiftPayBreakdown(for shift: Shift) throws(PayRateResolutionError) -> ShiftPayBreakdown {
        let context = try calculationContext(for: shift)
        let amount = context.workType.basePay(for: shift, using: context.applicablePayRate)

        return ShiftPayBreakdown(
            shift: shift,
            basePayBasis: context.workType.basePayBasis,
            appliedPayRate: context.applicablePayRate,
            paidDuration: shift.paidDuration,
            basePay: amount
        )
    }

    func payCalculationPeriod(
        for shift: Shift
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod {
        guard shift.jobID == job.id else {
            throw .foreignShiftOwner(shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID)
        }
        switch job.payCalculationCycle {
        case .perShift:
            return .perShift(shiftID: shift.id)
        case let .scheduled(schedule):
            return .scheduled(try scheduledPayPeriod(containing: shift.start, schedule: schedule))
        }
    }

    func payCalculationPeriod(
        containing date: Date
    ) throws(PayCalculationPeriodResolutionError) -> PayCalculationPeriod? {
        switch job.payCalculationCycle {
        case .perShift:
            return nil
        case let .scheduled(schedule):
            return .scheduled(try scheduledPayPeriod(containing: date, schedule: schedule))
        }
    }

    func contains(
        _ shift: Shift,
        in period: PayCalculationPeriod
    ) throws(ShiftMembershipError) -> Bool {
        guard shift.jobID == job.id else {
            throw .foreignShiftOwner(shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID)
        }
        switch period {
        case let .perShift(shiftID):
            return shift.id == shiftID
        case let .scheduled(payPeriod):
            guard let timeZone = TimeZone(identifier: job.timeZoneIdentifier) else {
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
        for shift in shifts where shift.jobID != job.id {
            throw .membershipFailed(.foreignShiftOwner(
                shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
            ))
        }
        let orderedShifts = shifts.sorted(by: Job.isShiftOrderedBefore)

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

    func paycheckComparison(
        for period: PayCalculationPeriod,
        actualGross: ActualGross,
        from shifts: [Shift]
    ) throws(ExpectedGrossCalculationError) -> PaycheckComparison {
        let expected = try expectedGrossBreakdown(for: period, from: shifts)

        return PaycheckComparison(expected: expected, actualGross: actualGross)
    }

    private func scheduledPayPeriod(
        containing date: Date,
        schedule: PayPeriodSchedule
    ) throws(PayCalculationPeriodResolutionError) -> PayPeriod {
        guard let timeZone = TimeZone(identifier: job.timeZoneIdentifier) else {
            throw PayCalculationPeriodResolutionError.invalidJobTimeZoneIdentifier
        }

        let localDate: LocalDate
        do {
            localDate = try LocalDate(date: date, in: timeZone)
        } catch {
            throw PayCalculationPeriodResolutionError.localDateConversionFailed(error)
        }

        do {
            return try schedule.period(containing: localDate)
        } catch {
            throw PayCalculationPeriodResolutionError.scheduledPeriodResolutionFailed
        }
    }

    private func calculationContext(for shift: Shift) throws(PayRateResolutionError) -> ShiftCalculationContext {
        let workType = try compensationWorkType(for: shift)
        let localStartDate = try localStartDate(for: shift)
        let payRate = workType.applicablePayRate(on: localStartDate)
        return ShiftCalculationContext(
            workType: workType,
            applicablePayRate: payRate
        )
    }

    private func compensationWorkType(for shift: Shift) throws(PayRateResolutionError) -> WorkType {
        guard shift.jobID == job.id else {
            throw .foreignShiftOwner(shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID)
        }
        guard let workType = job.workType(id: shift.workTypeID) else {
            throw PayRateResolutionError.workTypeNotFound(workTypeID: shift.workTypeID)
        }
        return workType
    }

    private func localStartDate(for shift: Shift) throws(PayRateResolutionError) -> LocalDate {
        guard let timeZone = TimeZone(identifier: job.timeZoneIdentifier) else {
            throw PayRateResolutionError.invalidJobTimeZoneIdentifier
        }

        do {
            return try LocalDate(date: shift.start, in: timeZone)
        } catch {
            throw PayRateResolutionError.localDateConversionFailed(error)
        }
    }
}
