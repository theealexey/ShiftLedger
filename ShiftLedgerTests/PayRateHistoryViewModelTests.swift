import Foundation
import Testing
@testable import ShiftLedger

struct PayRateHistoryViewModelTests {
    private let locale = Locale(identifier: "en_US")
    private let timeZoneIdentifier = "Pacific/Kiritimati"

    @Test("Fallback-only hourly history presents one initial rate")
    func fallbackOnlyHourly() throws {
        let fallback = try PayRate(id: id(1), amount: 12, effectiveFrom: nil)
        let workType = try makeWorkType(
            name: "Teaching",
            basis: .hourly,
            rates: [fallback]
        )

        let viewModel = PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        )

        #expect(viewModel.workTypeName == "Teaching")
        #expect(viewModel.rows.count == 1)
        #expect(viewModel.rows[0].id == fallback.id)
        #expect(viewModel.rows[0].kind == .initial)
        #expect(viewModel.rows[0].effectiveDateDescription == PayRateHistoryStrings.initialRate)
        #expect(viewModel.rows[0].amountAndBasis == PaycheckResultFormatting.rate(
            amount: 12,
            basis: .hourly,
            currencyCode: "USD",
            locale: locale
        ))
    }

    @Test("Dated rates are newest-first and fallback remains last exactly once")
    func ordersEveryRateExactlyOnce() throws {
        let fallback = try PayRate(id: id(1), amount: 10, effectiveFrom: nil)
        let oldest = try PayRate(
            id: id(2),
            amount: 12,
            effectiveFrom: LocalDate(year: 2025, month: 1, day: 15)
        )
        let newest = try PayRate(
            id: id(3),
            amount: 15,
            effectiveFrom: LocalDate(year: 2026, month: 9, day: 27)
        )
        let workType = try makeWorkType(
            name: "Teaching",
            basis: .hourly,
            rates: [newest, fallback, oldest]
        )

        let rows = PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        ).rows

        #expect(rows.map(\.id) == [newest.id, oldest.id, fallback.id])
        #expect(Set(rows.map(\.id)) == Set([fallback.id, oldest.id, newest.id]))
        #expect(rows.map(\.kind) == [
            .effectiveFrom(try LocalDate(year: 2026, month: 9, day: 27)),
            .effectiveFrom(try LocalDate(year: 2025, month: 1, day: 15)),
            .initial
        ])
    }

    @Test("Fixed-per-shift history uses the per-shift basis")
    func fixedPerShiftBasis() throws {
        let workType = try makeWorkType(
            name: "Event",
            basis: .fixedPerShift,
            rates: [try PayRate(amount: 120, effectiveFrom: nil)]
        )

        let row = try #require(PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        ).rows.first)

        #expect(row.amountAndBasis == PaycheckResultFormatting.rate(
            amount: 120,
            basis: .fixedPerShift,
            currencyCode: "USD",
            locale: locale
        ))
        #expect(row.accessibilityLabel == PayRateHistoryStrings.accessibilityInitialRate(
            PayRateHistoryStrings.accessibilityPerShiftRate(
                PaycheckResultFormatting.currency(120, currencyCode: "USD", locale: locale),
                locale: locale
            ),
            locale: locale
        ))
    }

    @Test("Unnamed WorkType uses the established truthful fallback")
    func unnamedWorkTypeContext() throws {
        let workType = try makeWorkType(
            name: nil,
            basis: .hourly,
            rates: [try PayRate(amount: 10, effectiveFrom: nil)]
        )

        let viewModel = PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        )

        #expect(viewModel.workTypeName == WorkTypesStrings.unnamed)
    }

    @Test("Dated presentation preserves the LocalDate in the Job timezone")
    func preservesLocalDate() throws {
        let localDate = try LocalDate(year: 2026, month: 1, day: 1)
        let workType = try makeWorkType(
            name: "Teaching",
            basis: .hourly,
            rates: [
                try PayRate(amount: 10, effectiveFrom: nil),
                try PayRate(amount: 12, effectiveFrom: localDate)
            ]
        )

        let row = try #require(PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        ).rows.first)

        #expect(row.kind == .effectiveFrom(localDate))
        #expect(row.effectiveDateDescription.contains("Jan 1, 2026"))
        #expect(row.effectiveDateDescription.contains("Dec 31") == false)
    }

    @Test("Equal amounts on different dates remain distinct history entries")
    func repeatedAmountsRemainDistinct() throws {
        let firstDate = try LocalDate(year: 2025, month: 2, day: 1)
        let secondDate = try LocalDate(year: 2026, month: 2, day: 1)
        let rates = [
            try PayRate(id: id(1), amount: 10, effectiveFrom: nil),
            try PayRate(id: id(2), amount: 15, effectiveFrom: firstDate),
            try PayRate(id: id(3), amount: 15, effectiveFrom: secondDate)
        ]
        let workType = try makeWorkType(name: "Teaching", basis: .hourly, rates: rates)

        let rows = PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: locale
        ).rows

        #expect(rows.count == 3)
        #expect(rows[0].id == id(3))
        #expect(rows[1].id == id(2))
        #expect(rows[0].amountAndBasis == rows[1].amountAndBasis)
        #expect(rows[0].kind != rows[1].kind)
    }

    @Test("Russian display locale uses the canonical comma-decimal rate formatting")
    func russianDisplayLocaleUsesCanonicalRateFormatting() throws {
        let russianLocale = Locale(identifier: "ru_RU")
        let fallback = try PayRate(id: id(1), amount: 6, effectiveFrom: nil)
        let dated = try PayRate(
            id: id(2),
            amount: 12,
            effectiveFrom: LocalDate(year: 2026, month: 9, day: 27)
        )
        let workType = try makeWorkType(
            name: "Teaching",
            basis: .hourly,
            rates: [fallback, dated]
        )

        let rows = PayRateHistoryViewModel(
            workType: workType,
            currencyCode: "USD",
            timeZoneIdentifier: timeZoneIdentifier,
            displayLocale: russianLocale
        ).rows

        #expect(rows.map(\.amountAndBasis) == [
            PaycheckResultFormatting.rate(
                amount: 12,
                basis: .hourly,
                currencyCode: "USD",
                locale: russianLocale
            ),
            PaycheckResultFormatting.rate(
                amount: 6,
                basis: .hourly,
                currencyCode: "USD",
                locale: russianLocale
            )
        ])
        #expect(rows.allSatisfy { $0.amountAndBasis.contains(",") })
        #expect(rows.allSatisfy { $0.amountAndBasis.contains(".") == false })
    }

    private func makeWorkType(
        name: String?,
        basis: BasePayBasis,
        rates: [PayRate]
    ) throws -> WorkType {
        WorkType(
            id: id(42),
            name: name,
            basePayBasis: basis,
            payRateHistory: try PayRateHistory(payRates: rates)
        )
    }

    private func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
