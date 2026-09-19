import Foundation
import Testing
@testable import ShiftLedger

struct WorkTypeTests {
    private let hour: TimeInterval = 60 * 60

    @Test("WorkType exposes the supplied compensation basis")
    func exposesBasePayBasis() throws {
        let workType = try makeWorkType(basePayBasis: .fixedPerShift)

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
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [changedRate, initialRate])
        )

        #expect(workType.payRates == [initialRate, changedRate])
    }

    @Test("WorkType calculates hourly pay from paid duration")
    func calculatesHourlyPay() throws {
        let workType = try makeWorkType(basePayBasis: .hourly, amount: 20)
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
        let workType = try makeWorkType(basePayBasis: .fixedPerShift, amount: 180)
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
        basePayBasis: BasePayBasis,
        amount: Decimal = 100
    ) throws -> WorkType {
        let rate = try PayRate(amount: amount, effectiveFrom: nil)
        return WorkType(
            basePayBasis: basePayBasis,
            payRateHistory: try PayRateHistory(payRates: [rate])
        )
    }
}
