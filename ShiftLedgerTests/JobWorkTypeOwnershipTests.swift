import Foundation
import Testing
@testable import ShiftLedger

struct JobWorkTypeOwnershipTests {
    private let jobID = UUID(uuid: (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1))
    private let lectureID = UUID(uuid: (2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2))
    private let examID = UUID(uuid: (3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3))
    private let unknownWorkTypeID = UUID(uuid: (4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4))

    @Test("Canonical Job принимает один WorkType")
    func acceptsOneWorkType() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)

        let job = try makeJob(workTypes: [lecture])

        #expect(job.workTypes == [lecture])
        #expect(job.soleWorkType == lecture)
    }

    @Test("Canonical Job владеет несколькими независимыми WorkType")
    func acceptsMultipleWorkTypes() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 5_000)

        let job = try makeJob(workTypes: [lecture, exam])

        #expect(job.workTypes == [lecture, exam])
        #expect(job.workTypes.map(\.basePayBasis) == [.hourly, .fixedPerShift])
        #expect(job.workTypes.map { $0.payRates.map(\.amount) } == [[3_000], [5_000]])
        #expect(job.soleWorkType == nil)
    }

    @Test("Canonical Job отклоняет пустую коллекцию WorkType")
    func rejectsMissingWorkTypes() {
        #expect(throws: JobValidationError.missingWorkTypes) {
            try makeJob(workTypes: [])
        }
    }

    @Test("Canonical Job отклоняет повторяющийся WorkType ID")
    func rejectsDuplicateWorkTypeIdentity() throws {
        let hourly = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)
        let fixed = try makeWorkType(id: lectureID, basis: .fixedPerShift, amount: 5_000)

        #expect(throws: JobValidationError.duplicateWorkTypeID) {
            try makeJob(workTypes: [hourly, fixed])
        }
    }

    @Test("Порядок WorkType нормализуется по UUID")
    func normalizesWorkTypeOrderForEquality() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 5_000)

        let forward = try makeJob(workTypes: [lecture, exam])
        let reversed = try makeJob(workTypes: [exam, lecture])

        #expect(forward == reversed)
        #expect(forward.workTypes.map(\.id) == [lectureID, examID])
    }

    @Test("WorkType lookup использует точный UUID")
    func looksUpWorkTypeByIdentity() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 5_000)
        let job = try makeJob(workTypes: [lecture, exam])

        #expect(job.workType(id: examID) == exam)
        #expect(job.workType(id: unknownWorkTypeID) == nil)
    }

    @Test("Legacy initializer создаёт один WorkType с identity Job")
    func legacyInitializerPreservesSingleWorkTypeContract() throws {
        let initial = try PayRate(amount: 3_000, effectiveFrom: nil)
        let changed = try PayRate(
            amount: 3_500,
            effectiveFrom: try LocalDate(year: 2026, month: 10, day: 1)
        )

        let job = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [changed, initial],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let workType = try #require(job.soleWorkType)

        #expect(workType.id == job.id)
        #expect(workType.basePayBasis == .hourly)
        #expect(workType.payRates == [initial, changed])
    }

    @Test("Multi-WorkType Job требует явного назначения для прямых расчётов")
    func multiWorkTypeJobRejectsDirectCompensationResolution() throws {
        let job = try makeMultiWorkTypeJob()
        let shift = try makeShift()

        #expect(throws: PayRateResolutionError.workTypeAssignmentRequired) {
            try job.applicablePayRate(for: shift)
        }
        #expect(throws: PayRateResolutionError.workTypeAssignmentRequired) {
            try job.basePay(for: shift)
        }
    }

    @Test("Multi-WorkType Job передаёт typed failure через aggregate расчёты")
    func multiWorkTypeJobRejectsAggregateCalculations() throws {
        let job = try makeMultiWorkTypeJob()
        let shift = try makeShift()
        let period = PayCalculationPeriod.perShift(shiftID: shift.id)
        let expectedError = ExpectedGrossCalculationError.basePayFailed(
            .workTypeAssignmentRequired
        )

        #expect(throws: expectedError) {
            try job.expectedGrossBreakdown(for: period, from: [shift])
        }
        #expect(throws: expectedError) {
            try job.expectedGross(for: period, from: [shift])
        }
        #expect(throws: expectedError) {
            try job.paycheckComparison(
                for: period,
                actualGross: try ActualGross(amount: 0),
                from: [shift]
            )
        }
    }

    private func makeJob(workTypes: [WorkType]) throws -> Job {
        try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: workTypes,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    private func makeMultiWorkTypeJob() throws -> Job {
        try makeJob(workTypes: [
            makeWorkType(id: lectureID, basis: .hourly, amount: 20),
            makeWorkType(id: examID, basis: .fixedPerShift, amount: 500)
        ])
    }

    private func makeWorkType(
        id: UUID,
        basis: BasePayBasis,
        amount: Decimal
    ) throws -> WorkType {
        WorkType(
            id: id,
            basePayBasis: basis,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(amount: amount, effectiveFrom: nil)]
            )
        )
    }

    private func makeShift() throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        return try Shift(
            start: start,
            end: start.addingTimeInterval(8 * 60 * 60)
        )
    }
}
