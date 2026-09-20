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
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

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
        let shift = try Shift(start: start, end: start.addingTimeInterval(8 * hour))

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
