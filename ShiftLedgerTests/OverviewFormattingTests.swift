import Foundation
import Testing
@testable import ShiftLedger

struct OverviewFormattingTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test("Expected gross uses the requested currency code")
    func expectedGrossUsesCurrencyCode() throws {
        let amount = try decimal("1234.56")

        let result = OverviewFormatting.currency(
            amount,
            currencyCode: "EUR",
            locale: locale
        )

        #expect(result.contains("€"))
        #expect(result.contains("1234.56"))
    }

    @Test("Currency formatting leaves the source Decimal unchanged")
    func currencyFormattingPreservesDecimal() throws {
        let amount = try decimal("1234.56789")
        let original = amount

        _ = OverviewFormatting.currency(amount, currencyCode: "EUR", locale: locale)

        #expect(amount == original)
    }

    @Test("Currency formatting does not force two fraction digits")
    func currencyFormattingUsesCurrencyConvention() {
        let result = OverviewFormatting.currency(
            Decimal(1_234),
            currencyCode: "JPY",
            locale: locale
        )

        #expect(result.contains(".00") == false)
    }

    @Test("Weekly period displays its inclusive visible end date")
    func weeklyPeriodUsesInclusiveEnd() throws {
        let period = PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 7),
            endExclusive: try localDate(year: 2026, month: 9, day: 14)
        )

        let result = try #require(OverviewFormatting.scheduledPeriod(
            period,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(result.contains("Sep"))
        #expect(result.contains("7"))
        #expect(result.contains("13"))
        #expect(result.contains("14") == false)
    }

    @Test("Monthly period displays the last day instead of endExclusive")
    func monthlyPeriodUsesLastVisibleDay() throws {
        let period = PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )

        let result = try #require(OverviewFormatting.scheduledPeriod(
            period,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(result.contains("Sep"))
        #expect(result.contains("30"))
        #expect(result.contains("Oct") == false)
    }

    @Test("Scheduled period formats a year boundary")
    func scheduledPeriodFormatsYearBoundary() throws {
        let period = PayPeriod(
            start: try localDate(year: 2025, month: 12, day: 29),
            endExclusive: try localDate(year: 2026, month: 1, day: 5)
        )

        let result = try #require(OverviewFormatting.scheduledPeriod(
            period,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(result.contains("Dec"))
        #expect(result.contains("Jan"))
        #expect(result.contains("2025"))
        #expect(result.contains("2026"))
        #expect(result.contains("4"))
    }

    @Test("Per-shift period renders local date and time")
    func perShiftUsesJobTimeZone() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 20, hour: 0, minute: 0),
            duration: 8 * 60 * 60
        )

        let result = try #require(OverviewFormatting.perShiftPeriod(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(result.contains("Sep 20"))
        #expect(result.contains("2:00"))
        #expect(result.contains("10:00"))
    }

    @Test("The same Shift instant follows the supplied Job timezone")
    func sameInstantUsesSuppliedTimeZone() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 20, hour: 0, minute: 30),
            duration: 60 * 60
        )

        let stockholm = try #require(OverviewFormatting.perShiftPeriod(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))
        let newYork = try #require(OverviewFormatting.perShiftPeriod(
            shift,
            timeZoneIdentifier: "America/New_York",
            locale: locale
        ))

        #expect(stockholm.contains("Sep 20"))
        #expect(newYork.contains("Sep 19"))
        #expect(stockholm != newYork)
    }

    @Test("Formatting is deterministic for an injected Locale")
    func formattingUsesInjectedLocaleDeterministically() throws {
        let period = PayPeriod(
            start: try localDate(year: 2026, month: 9, day: 1),
            endExclusive: try localDate(year: 2026, month: 10, day: 1)
        )

        let first = OverviewFormatting.scheduledPeriod(
            period,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        )
        let second = OverviewFormatting.scheduledPeriod(
            period,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        )

        #expect(first == second)
    }

    @Test("Explicit timezone output does not depend on device timezone")
    func formattingHasNoDeviceTimeZoneDependency() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 20, hour: 12, minute: 0),
            duration: 60 * 60
        )

        let utc = try #require(OverviewFormatting.perShiftPeriod(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))
        let stockholm = try #require(OverviewFormatting.perShiftPeriod(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(utc.contains("12:00"))
        #expect(stockholm.contains("2:00"))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: locale))
    }

    private func localDate(year: Int, month: Int, day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    private func makeShift(start: Date, duration: TimeInterval) throws -> Shift {
        try Shift(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            start: start,
            end: start.addingTimeInterval(duration)
        )
    }
}
