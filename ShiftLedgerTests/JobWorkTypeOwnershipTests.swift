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

    @Test("Adding a rate updates only the exact WorkType and preserves Job metadata")
    func addsPayRateToExactWorkType() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 20)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 500)
        let original = try makeJob(workTypes: [lecture, exam])
        let added = try PayRate(
            id: UUID(uuid: (8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            amount: 30,
            effectiveFrom: LocalDate(year: 2001, month: 1, day: 2)
        )

        let updated = try original.addingPayRate(added, toWorkTypeID: examID)

        #expect(updated.id == original.id)
        #expect(updated.currencyCode == original.currencyCode)
        #expect(updated.timeZoneIdentifier == original.timeZoneIdentifier)
        #expect(updated.payCalculationCycle == original.payCalculationCycle)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.workTypes.map(\.id) == original.workTypes.map(\.id))
        #expect(updated.workType(id: lectureID) == lecture)
        #expect(updated.workType(id: examID)?.payRates == exam.payRates + [added])
        #expect(original.workType(id: examID) == exam)
    }

    @Test("Unknown WorkType ID never falls back to another WorkType")
    func rejectsPayRateForUnknownWorkType() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 20)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 500)
        let original = try makeJob(workTypes: [lecture, exam])
        let added = try PayRate(
            amount: 30,
            effectiveFrom: LocalDate(year: 2001, month: 1, day: 2)
        )

        #expect(throws: JobPayRateChangeError.workTypeNotFound(workTypeID: unknownWorkTypeID)) {
            try original.addingPayRate(added, toWorkTypeID: unknownWorkTypeID)
        }
        #expect(original.workType(id: lectureID) == lecture)
        #expect(original.workType(id: examID) == exam)
    }

    @Test("Renaming one WorkType preserves Job metadata and historical compensation")
    func renamingWorkTypePreservesAggregateAndPay() throws {
        let initial = try PayRate(
            id: UUID(uuid: (5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            amount: 20,
            effectiveFrom: nil
        )
        let dated = try PayRate(
            id: UUID(uuid: (5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
            amount: 25,
            effectiveFrom: LocalDate(year: 2001, month: 1, day: 2)
        )
        let lecture = WorkType(
            id: lectureID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [dated, initial])
        )
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 500)
        let original = try makeJob(workTypes: [lecture, exam])
        let beforeShift = try makeShift(workTypeID: lectureID, startOffset: 0, hours: 2)
        let afterShift = try makeShift(workTypeID: lectureID, startOffset: 2 * 24 * 60 * 60, hours: 2)
        let beforeRate = try original.applicablePayRate(for: beforeShift)
        let afterRate = try original.applicablePayRate(for: afterShift)
        let beforePay = try original.basePay(for: beforeShift)
        let afterPay = try original.basePay(for: afterShift)
        let beforeGross = try original.expectedGross(
            for: .perShift(shiftID: beforeShift.id), from: [beforeShift, afterShift]
        )
        let afterGross = try original.expectedGross(
            for: .perShift(shiftID: afterShift.id), from: [beforeShift, afterShift]
        )

        let renamed = try original.renamingWorkType(id: lectureID, to: "  Senior Lectures \n")

        #expect(renamed.id == original.id)
        #expect(renamed.currencyCode == original.currencyCode)
        #expect(renamed.timeZoneIdentifier == original.timeZoneIdentifier)
        #expect(renamed.payCalculationCycle == original.payCalculationCycle)
        #expect(renamed.createdAt == original.createdAt)
        #expect(renamed.workTypes.map(\.id) == original.workTypes.map(\.id))
        #expect(renamed.workType(id: lectureID)?.name == "Senior Lectures")
        #expect(renamed.workType(id: lectureID)?.payRates == [initial, dated])
        #expect(renamed.workType(id: examID) == exam)
        #expect(original.workType(id: lectureID)?.name == "Lectures")
        #expect(try renamed.applicablePayRate(for: beforeShift) == beforeRate)
        #expect(try renamed.applicablePayRate(for: afterShift) == afterRate)
        #expect(try renamed.basePay(for: beforeShift) == beforePay)
        #expect(try renamed.basePay(for: afterShift) == afterPay)
        #expect(try renamed.expectedGross(
            for: .perShift(shiftID: beforeShift.id), from: [beforeShift, afterShift]
        ) == beforeGross)
        #expect(try renamed.expectedGross(
            for: .perShift(shiftID: afterShift.id), from: [beforeShift, afterShift]
        ) == afterGross)
    }

    @Test("Rename maps unknown identity and blank name to exact errors")
    func rejectsInvalidWorkTypeRename() throws {
        let job = try makeJob(workTypes: [
            makeWorkType(id: lectureID, basis: .hourly, amount: 20)
        ])

        #expect(throws: JobWorkTypeRenameError.workTypeNotFound(workTypeID: unknownWorkTypeID)) {
            try job.renamingWorkType(id: unknownWorkTypeID, to: "Exams")
        }
        #expect(throws: JobWorkTypeRenameError.invalidName(.empty)) {
            try job.renamingWorkType(id: lectureID, to: "\n  ")
        }
    }

    @Test("Equal display names do not merge distinct WorkType identities")
    func renameAllowsDuplicateDisplayName() throws {
        let lecture = WorkType(
            id: lectureID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(amount: 20, effectiveFrom: nil)
            ])
        )
        let exam = WorkType(
            id: examID,
            name: "Exams",
            basePayBasis: .fixedPerShift,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(amount: 500, effectiveFrom: nil)
            ])
        )
        let original = try makeJob(workTypes: [lecture, exam])

        let renamed = try original.renamingWorkType(id: examID, to: "Lectures")

        #expect(renamed.workTypes.map(\.id) == [lectureID, examID])
        #expect(renamed.workTypes.map(\.name) == ["Lectures", "Lectures"])
        #expect(renamed.workType(id: lectureID) == lecture)
        #expect(renamed.workType(id: examID)?.basePayBasis == .fixedPerShift)
        #expect(original.workType(id: examID)?.name == "Exams")
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

    @Test("Multi-WorkType Job рассчитывает точный назначенный WorkType")
    func multiWorkTypeJobResolvesAssignedCompensation() throws {
        let job = try makeMultiWorkTypeJob()
        let lectureShift = try makeShift(workTypeID: lectureID)
        let examShift = try makeShift(workTypeID: examID)

        #expect(try job.applicablePayRate(for: lectureShift).amount == 20)
        #expect(try job.basePay(for: lectureShift) == 160)
        #expect(try job.applicablePayRate(for: examShift).amount == 500)
        #expect(try job.basePay(for: examShift) == 500)
    }

    @Test("Неизвестный WorkType отклоняется без sole fallback")
    func unknownWorkTypeFailsDirectAndAggregateCalculations() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 20)
        let job = try makeJob(workTypes: [lecture])
        let shift = try makeShift(workTypeID: unknownWorkTypeID)
        let period = PayCalculationPeriod.perShift(shiftID: shift.id)
        let expectedError = ExpectedGrossCalculationError.basePayFailed(
            .workTypeNotFound(workTypeID: unknownWorkTypeID)
        )

        #expect(throws: PayRateResolutionError.workTypeNotFound(workTypeID: unknownWorkTypeID)) {
            try job.applicablePayRate(for: shift)
        }
        #expect(throws: PayRateResolutionError.workTypeNotFound(workTypeID: unknownWorkTypeID)) {
            try job.basePay(for: shift)
        }
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

    @Test("Смешанные WorkType дают объяснимый expected gross и paycheck comparison")
    func mixedWorkTypesComposeExpectedGross() throws {
        let lecture = try makeWorkType(id: lectureID, basis: .hourly, amount: 3_000)
        let exam = try makeWorkType(id: examID, basis: .fixedPerShift, amount: 5_000)
        let job = try makeJob(workTypes: [exam, lecture])
        let lectureShift = try makeShift(workTypeID: lectureID, hours: 2)
        let examShift = try makeShift(
            workTypeID: examID,
            startOffset: 100_000 + 3 * 60 * 60,
            hours: 3
        )
        let period = PayCalculationPeriod.scheduled(PayPeriod(
            start: try LocalDate(year: 2001, month: 1, day: 1),
            endExclusive: try LocalDate(year: 2001, month: 1, day: 3)
        ))

        let breakdown = try job.expectedGrossBreakdown(
            for: period,
            from: [examShift, lectureShift]
        )
        let comparison = try job.paycheckComparison(
            for: period,
            actualGross: try ActualGross(amount: 12_000),
            from: [examShift, lectureShift]
        )

        #expect(breakdown.expectedGross == 11_000)
        #expect(breakdown.shiftBreakdowns.map(\.shift.workTypeID) == [lectureID, examID])
        #expect(breakdown.shiftBreakdowns.map(\.basePayBasis) == [.hourly, .fixedPerShift])
        #expect(breakdown.shiftBreakdowns.map(\.basePay) == [6_000, 5_000])
        #expect(comparison.expected.expectedGross == 11_000)
        #expect(comparison.difference == 1_000)
    }

    @Test("WorkType разрешают независимые истории ставок на одной local date")
    func workTypesResolveIndependentRateHistories() throws {
        let effectiveDate = try LocalDate(year: 2001, month: 1, day: 2)
        let lectureInitial = try PayRate(amount: 20, effectiveFrom: nil)
        let lectureChanged = try PayRate(amount: 25, effectiveFrom: effectiveDate)
        let examInitial = try PayRate(amount: 100, effectiveFrom: nil)
        let examChanged = try PayRate(amount: 150, effectiveFrom: effectiveDate)
        let lecture = WorkType(
            id: lectureID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [lectureInitial, lectureChanged])
        )
        let exam = WorkType(
            id: examID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [examInitial, examChanged])
        )
        let job = try makeJob(workTypes: [lecture, exam])
        let lectureShift = try makeShift(workTypeID: lectureID, startOffset: 2 * 24 * 60 * 60)
        let examShift = try makeShift(workTypeID: examID, startOffset: 2 * 24 * 60 * 60)

        #expect(try job.applicablePayRate(for: lectureShift) == lectureChanged)
        #expect(try job.applicablePayRate(for: examShift) == examChanged)
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

    private func makeShift(
        workTypeID: UUID,
        startOffset: TimeInterval = 100_000,
        hours: TimeInterval = 8
    ) throws -> Shift {
        let start = Date(timeIntervalSinceReferenceDate: startOffset)
        return try Shift(
            workTypeID: workTypeID,
            start: start,
            end: start.addingTimeInterval(hours * 60 * 60)
        )
    }
}
