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
