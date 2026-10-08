import Foundation
import Testing
@testable import ShiftLedger

struct JobShiftOwnershipTests {
    private let jobID = UUID(uuid: (0x89, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let foreignJobID = UUID(uuid: (0x89, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let workTypeID = UUID(uuid: (0x89, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("Explicit Job ownership is independent of Shift identity and valid payroll is unchanged")
    func matchingOwner() throws {
        let job = try makeJob()
        let shift = try makeShift(jobID: job.id)
        #expect(shift.jobID == job.id)
        #expect(shift.id != job.id)
        try job.validateNewShiftAssignment(shift)
        #expect(try job.applicablePayRate(for: shift).amount == 100)
        #expect(try job.basePay(for: shift) == 100)
        let period = try job.payCalculationPeriod(for: shift)
        #expect(try job.contains(shift, in: period))
        #expect(try job.expectedGross(for: period, from: [shift]) == 100)
    }

    @Test("Every single-Shift Job boundary rejects a foreign owner even with a matching WorkType UUID")
    func rejectsForeignOwner() throws {
        let job = try makeJob()
        let foreignJob = try makeJob(id: foreignJobID)
        let shift = try makeShift(jobID: foreignJob.id)
        try foreignJob.validateNewShiftAssignment(shift)
        #expect(throws: JobShiftAssignmentError.foreignShiftOwner(
            shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
        )) { try job.validateNewShiftAssignment(shift) }
        let rateError = PayRateResolutionError.foreignShiftOwner(
            shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
        )
        #expect(throws: rateError) { try job.applicablePayRate(for: shift) }
        #expect(throws: rateError) { try job.basePay(for: shift) }
        #expect(throws: PayCalculationPeriodResolutionError.foreignShiftOwner(
            shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
        )) { try job.payCalculationPeriod(for: shift) }
        let membershipError = ShiftMembershipError.foreignShiftOwner(
            shiftID: shift.id, expectedJobID: job.id, actualJobID: shift.jobID
        )
        #expect(throws: membershipError) { try job.contains(shift, in: .perShift(shiftID: UUID())) }
        let outsidePeriod = PayPeriod(
            start: try LocalDate(year: 2020, month: 1, day: 1),
            endExclusive: try LocalDate(year: 2020, month: 2, day: 1)
        )
        #expect(throws: membershipError) { try job.contains(shift, in: .scheduled(outsidePeriod)) }
    }

    @Test("Gross and paycheck comparison reject foreign input outside the selected period")
    func rejectsMixedOwners() throws {
        let job = try makeJob()
        let owned = try makeShift(jobID: job.id)
        let foreign = try makeShift(jobID: foreignJobID, offset: 86_400)
        let period = try job.payCalculationPeriod(for: owned)
        let error = ExpectedGrossCalculationError.membershipFailed(.foreignShiftOwner(
            shiftID: foreign.id, expectedJobID: job.id, actualJobID: foreign.jobID
        ))
        #expect(throws: error) { try job.expectedGrossBreakdown(for: period, from: [owned, foreign]) }
        #expect(throws: error) { try job.expectedGross(for: period, from: [owned, foreign]) }
        let actual = try ActualGross(amount: 100)
        #expect(throws: error) { try job.paycheckComparison(for: period, actualGross: actual, from: [owned, foreign]) }
    }

    @Test("Historical rate protection rejects foreign input before WorkType and asOf filtering",
          arguments: [false, true])
    func rejectsForeignHistoricalInput(_ future: Bool) throws {
        let job = try makeJob()
        let foreign = try Shift(jobID: foreignJobID, workTypeID: testWorkTypeID,
            start: start, end: start.addingTimeInterval(3_600))
        let rate = try PayRate(amount: 100, effectiveFrom: LocalDate(year: 2030, month: 1, day: 1))
        #expect(throws: JobPayRateChangeError.foreignShiftOwner(
            shiftID: foreign.id, expectedJobID: job.id, actualJobID: foreign.jobID
        )) {
            try job.addingPayRate(rate, toWorkTypeID: workTypeID,
                preservingHistoricalPayrollFor: [foreign],
                asOf: start.addingTimeInterval(future ? -1 : 1))
        }
    }

    @Test("Overlap remains a time predicate across different Job owners")
    func overlapDoesNotFilterOwnership() throws {
        let first = try makeShift(jobID: jobID)
        let second = try makeShift(jobID: foreignJobID)
        #expect(first.overlaps(with: second))
        #expect(second.overlaps(with: first))
    }

    private func makeJob(id: UUID? = nil) throws -> Job {
        try Job(id: id ?? jobID, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift, workTypes: [WorkType(id: workTypeID,
                basePayBasis: .hourly, payRateHistory: PayRateHistory(payRates: [
                    PayRate(amount: 100, effectiveFrom: nil)
                ]))])
    }

    private func makeShift(jobID: UUID, offset: TimeInterval = 0) throws -> Shift {
        try Shift(jobID: jobID, workTypeID: workTypeID,
            start: start.addingTimeInterval(offset), end: start.addingTimeInterval(offset + 3_600))
    }
}
