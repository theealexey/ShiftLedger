import Foundation
import Testing
@testable import ShiftLedger

struct WorkTypeTests {
    private let hour: TimeInterval = 60 * 60
    private let primaryWorkTypeID = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
    private let secondaryWorkTypeID = UUID(uuid: (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17))
    private let jobID = UUID(uuid: (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18))
    private let payRateID = UUID(uuid: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19))

    @Test("WorkType preserves its explicitly supplied identity")
    func preservesExplicitIdentity() throws {
        let workType = try makeWorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly
        )

        #expect(workType.id == primaryWorkTypeID)
    }

    @Test("WorkType preserves an explicitly supplied name")
    func preservesExplicitName() throws {
        let workType = WorkType(
            id: primaryWorkTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)]
            )
        )

        #expect(workType.name == "Lectures")
    }

    @Test("WorkType name defaults to nil")
    func defaultsNameToNil() throws {
        let workType = try makeWorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly
        )

        #expect(workType.name == nil)
    }

    @Test("WorkType name participates in value equality")
    func nameParticipatesInEquality() throws {
        let payRateHistory = try PayRateHistory(
            payRates: [try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)]
        )
        let first = WorkType(
            id: primaryWorkTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: payRateHistory
        )
        let second = WorkType(
            id: primaryWorkTypeID,
            name: "Exams",
            basePayBasis: .hourly,
            payRateHistory: payRateHistory
        )

        #expect(first != second)
    }

    @Test("Rename changes only the WorkType name and preserves its original value")
    func renamePreservesCompensationAndOriginal() throws {
        let initial = try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)
        let dated = try PayRate(
            id: UUID(uuid: (5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5)),
            amount: 125,
            effectiveFrom: LocalDate(year: 2026, month: 9, day: 1)
        )
        let original = WorkType(
            id: primaryWorkTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [initial, dated])
        )

        let renamed = try original.renamed(to: " \n Night   SHIFT \t ")

        #expect(renamed.name == "Night   SHIFT")
        #expect(renamed.id == original.id)
        #expect(renamed.basePayBasis == original.basePayBasis)
        #expect(renamed.payRates == original.payRates)
        #expect(original.name == "Lectures")
        #expect(renamed.applicablePayRate(on: try LocalDate(year: 2026, month: 9, day: 1)) == dated)
    }

    @Test("Whitespace-only WorkType rename is rejected")
    func rejectsEmptyRenamedName() throws {
        let original = try makeWorkType(id: primaryWorkTypeID, basePayBasis: .hourly)

        #expect(throws: WorkTypeNameValidationError.empty) {
            try original.renamed(to: " \n\t ")
        }
        #expect(original.name == nil)
    }

    @Test("Historical nil-named WorkType accepts a real name")
    func renamesHistoricalNilName() throws {
        let original = try makeWorkType(id: primaryWorkTypeID, basePayBasis: .fixedPerShift)

        let renamed = try original.renamed(to: "Экзамен!")

        #expect(original.name == nil)
        #expect(renamed.name == "Экзамен!")
        #expect(renamed.id == original.id)
        #expect(renamed.payRates == original.payRates)
    }

    @Test("WorkType identity participates in value equality")
    func identityParticipatesInEquality() throws {
        let payRate = try PayRate(
            id: payRateID,
            amount: 100,
            effectiveFrom: nil
        )
        let payRateHistory = try PayRateHistory(payRates: [payRate])
        let first = WorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: payRateHistory
        )
        let second = WorkType(
            id: secondaryWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: payRateHistory
        )

        #expect(first != second)
    }

    @Test("Legacy Job initializer uses Job identity for its sole WorkType")
    func legacyJobUsesExplicitIdentityForSoleWorkType() throws {
        let job = try makeJob(id: jobID)
        let workType = try #require(job.soleWorkType)

        #expect(workType.id == jobID)
        #expect(workType.id == job.id)
        #expect(workType.name == nil)
    }

    @Test("Legacy Job initializer supplies its sole WorkType name")
    func legacyJobSuppliesSoleWorkTypeName() throws {
        let job = try Job(
            id: jobID,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            workTypeName: "Lectures",
            payCalculationCycle: .perShift,
            payRates: [try PayRate(id: payRateID, amount: 100, effectiveFrom: nil)],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        let workType = try #require(job.soleWorkType)

        #expect(workType.id == job.id)
        #expect(workType.name == "Lectures")
    }

    @Test("Job default initializer keeps WorkType identity aligned")
    func jobDefaultInitializerRemainsSourceCompatible() throws {
        let job = try Job(
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [
                try PayRate(
                    id: payRateID,
                    amount: 100,
                    effectiveFrom: nil
                )
            ],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )

        #expect(job.soleWorkType?.id == job.id)
    }

    @Test("WorkType exposes the supplied compensation basis")
    func exposesBasePayBasis() throws {
        let workType = try makeWorkType(
            id: primaryWorkTypeID,
            basePayBasis: .fixedPerShift
        )

        #expect(workType.basePayBasis == .fixedPerShift)
    }

    @Test("WorkType resolves the initial rate before the first change")
    func resolvesInitialRate() throws {
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let changedRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let workType = WorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [initialRate, changedRate])
        )

        #expect(
            workType.applicablePayRate(
                on: try LocalDate(year: 2026, month: 8, day: 31)
            ) == initialRate
        )
    }

    @Test("WorkType resolves a changed rate at its effective date")
    func resolvesHistoricalRateOnBoundary() throws {
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let changedRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let workType = WorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [initialRate, changedRate])
        )

        #expect(
            workType.applicablePayRate(
                on: try LocalDate(year: 2026, month: 9, day: 1)
            ) == changedRate
        )
    }

    @Test("WorkType exposes normalized pay rates")
    func exposesNormalizedPayRates() throws {
        let initialRate = try PayRate(amount: 1_000, effectiveFrom: nil)
        let changedRate = try PayRate(
            amount: 1_200,
            effectiveFrom: try LocalDate(year: 2026, month: 9, day: 1)
        )
        let workType = WorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [changedRate, initialRate])
        )

        #expect(workType.payRates == [initialRate, changedRate])
    }

    @Test("WorkType calculates hourly pay from paid duration")
    func calculatesHourlyPay() throws {
        let workType = try makeWorkType(
            id: primaryWorkTypeID,
            basePayBasis: .hourly,
            amount: 20
        )
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            workTypeID: workType.id,
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(
            workType.basePay(
                for: shift,
                on: try LocalDate(year: 2026, month: 9, day: 1)
            ) == Decimal(160)
        )
    }

    @Test("WorkType calculates fixed pay once per shift")
    func calculatesFixedPay() throws {
        let workType = try makeWorkType(
            id: primaryWorkTypeID,
            basePayBasis: .fixedPerShift,
            amount: 180
        )
        let start = Date(timeIntervalSinceReferenceDate: 100_000)
        let shift = try Shift(
            workTypeID: workType.id,
            start: start,
            end: start.addingTimeInterval(8 * hour)
        )

        #expect(
            workType.basePay(
                for: shift,
                on: try LocalDate(year: 2026, month: 9, day: 1)
            ) == Decimal(180)
        )
    }

    private func makeWorkType(
        id: UUID,
        basePayBasis: BasePayBasis,
        amount: Decimal = 100
    ) throws -> WorkType {
        let rate = try PayRate(amount: amount, effectiveFrom: nil)
        return WorkType(
            id: id,
            basePayBasis: basePayBasis,
            payRateHistory: try PayRateHistory(payRates: [rate])
        )
    }

    private func makeJob(id: UUID) throws -> Job {
        try Job(
            id: id,
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            basePayBasis: .hourly,
            payCalculationCycle: .perShift,
            payRates: [
                try PayRate(
                    id: payRateID,
                    amount: 100,
                    effectiveFrom: nil
                )
            ],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
