import Foundation
import Testing
@testable import ShiftLedger

struct OverviewFormattingTests {
    @Test("Hero formats numeric currency precision without currency text", arguments: ["SEK", "JPY", "KWD"])
    func heroUsesCurrencyPrecision(_ code: String) {
        let value = Decimal(2400)
        let result = OverviewFormatting.heroAmount(value, currencyCode: code, locale: Locale(identifier: "en_US"))
        #expect(result.contains(code) == false)
        #expect(result == (code == "JPY" ? "2,400" : code == "KWD" ? "2,400.000" : "2,400.00"))
    }

    @Test("Compact rail identifies monthly and weekly periods")
    func compactScheduledTitles() throws {
        let monthly = PayPeriod(start: try localDate(year: 2026, month: 9, day: 1), endExclusive: try localDate(year: 2026, month: 10, day: 1))
        #expect(OverviewFormatting.compactScheduledPeriod(monthly, timeZoneIdentifier: "UTC", locale: locale) == "September 2026")
        let weekly = PayPeriod(start: try localDate(year: 2026, month: 9, day: 7), endExclusive: try localDate(year: 2026, month: 9, day: 14))
        let text = try #require(OverviewFormatting.compactScheduledPeriod(weekly, timeZoneIdentifier: "UTC", locale: locale, referenceDate: try date(year: 2026, month: 9, day: 18, hour: 12, minute: 0)))
        #expect(text.contains("7"))
        #expect(text.contains("13"))
        #expect(!text.contains("2026"))
    }

    @Test("Compact overnight rail title contains only local Shift start")
    func compactShiftDoesNotRepeatInterval() throws {
        let start = try date(year: 2026, month: 9, day: 12, hour: 21, minute: 36)
        let shift = try makeShift(start: start, duration: 12 * 3600)
        let text = try #require(OverviewFormatting.compactPerShiftPeriod(shift, timeZoneIdentifier: "UTC", locale: locale, referenceDate: start))
        #expect(text.contains("Sep 12"))
        #expect(text.contains("9:36"))
        #expect(!text.contains("Sep 13"))
        #expect(!text.contains("2026"))
    }

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

    @Test("Shift card date and time use the supplied Job timezone")
    func shiftCardDateAndTimeUseJobTimeZone() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 20, hour: 0, minute: 30),
            duration: 90 * 60
        )

        let date = try #require(OverviewFormatting.shiftDate(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))
        let time = try #require(OverviewFormatting.shiftTimeRange(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(date.contains("Sep 20"))
        #expect(time.contains("2:30"))
        #expect(time.contains("4:00"))
    }

    @Test("Shift endpoints use the supplied Job timezone")
    func shiftEndpointsUseJobTimeZone() throws {
        let start = try date(year: 2026, month: 9, day: 19, hour: 23, minute: 30)
        let shift = try Shift(
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(2 * 60 * 60),
            unpaidBreak: UnpaidBreak(
                start: start.addingTimeInterval(60 * 60),
                end: start.addingTimeInterval(90 * 60)
            )
        )

        let utc = try #require(OverviewFormatting.shiftEndpoints(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))
        let stockholm = try #require(OverviewFormatting.shiftEndpoints(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(utc.startTime.contains("11:30"))
        #expect(utc.endTime.contains("1:30"))
        #expect(stockholm.startTime.contains("1:30"))
        #expect(stockholm.endTime.contains("3:30"))
        #expect(utc.startDate?.contains("19") == true)
        #expect(utc.endDate?.contains("20") == true)
        #expect(stockholm.startDate == nil)
        #expect(stockholm.endDate == nil)
    }

    @Test("Endpoint dates distinguish overnight and multi-day Shifts", arguments: [1, 2])
    func shiftEndpointsIdentifyDifferentDays(_ days: Int) throws {
        let start = try date(year: 2026, month: 9, day: 15, hour: 22, minute: 43)
        let shift = try makeShift(start: start, duration: Double(days) * 24 * 3600)
        let result = try #require(OverviewFormatting.shiftEndpoints(
            shift, timeZoneIdentifier: "UTC", locale: locale
        ))
        #expect(result.startDate?.contains("15") == true)
        #expect(result.endDate?.contains(String(15 + days)) == true)
        #expect(result.startDate != result.endDate)
        #expect(result.startTime == result.endTime)
    }

    @Test("Endpoint dates retain both years when a Shift crosses New Year")
    func shiftEndpointsIdentifyYearBoundary() throws {
        let start = try date(year: 2026, month: 12, day: 31, hour: 22, minute: 0)
        let shift = try makeShift(start: start, duration: 8 * 3600)
        let result = try #require(OverviewFormatting.shiftEndpoints(
            shift, timeZoneIdentifier: "UTC", locale: locale
        ))
        #expect(result.startDate?.contains("2026") == true)
        #expect(result.endDate?.contains("2027") == true)
    }

    @Test("Compact Shift date uses the supplied Job timezone")
    func frontShiftDateUsesJobTimeZone() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 19, hour: 23, minute: 30),
            duration: 60 * 60
        )

        let utc = try #require(OverviewFormatting.frontShiftDate(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))
        let stockholm = try #require(OverviewFormatting.frontShiftDate(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(utc.contains("19"))
        #expect(stockholm.contains("20"))
    }

    @Test("Same-day card header keeps only its time context beside compact date")
    func compactSameDayShiftHeaderContext() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 15, hour: 12, minute: 56),
            duration: 5 * 60 * 60
        )
        let locale = Locale(identifier: "en_GB")
        let time = try #require(OverviewFormatting.compactShiftTimeRange(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))

        #expect(time.contains("12:56"))
        #expect(time.contains("17:56"))
        #expect(time.contains("15") == false)
        #expect(time.contains("Sep") == false)
    }

    @Test("Overnight card header keeps only truthful end-date context")
    func compactOvernightShiftHeaderContext() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 15, hour: 22, minute: 43),
            duration: 8 * 60 * 60
        )
        let locale = Locale(identifier: "en_GB")
        let time = try #require(OverviewFormatting.compactShiftTimeRange(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))

        #expect(time.contains("22:43"))
        #expect(time.contains("06:43"))
        #expect(time.contains("16"))
        #expect(time.contains("15") == false)
    }

    @Test("Multi-day card header keeps only truthful end-date context")
    func compactMultiDayShiftHeaderContext() throws {
        let shift = try makeShift(
            start: try date(year: 2026, month: 9, day: 15, hour: 12, minute: 56),
            duration: 48 * 60 * 60
        )
        let locale = Locale(identifier: "en_GB")
        let time = try #require(OverviewFormatting.compactShiftTimeRange(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        ))

        #expect(time.contains("12:56"))
        #expect(time.contains("17"))
        #expect(time.contains("15") == false)
    }

    @Test("Shift card duration uses complete localized components")
    func shiftCardDurationUsesCompleteLocalizedComponents() {
        let result = OverviewFormatting.duration(8 * 3_600 + 30 * 60)

        #expect(result == "8 \(PaycheckResultStrings.durationHour) 30 \(PaycheckResultStrings.durationMinute)")
    }

    @Test("Expanded Shift break detail uses the Job timezone and local interval")
    func unpaidBreakIntervalUsesJobTimeZone() throws {
        let start = try date(year: 2026, month: 9, day: 20, hour: 8, minute: 0)
        let unpaidBreak = UnpaidBreak(
            start: start.addingTimeInterval(4 * 3_600),
            end: start.addingTimeInterval(4.5 * 3_600)
        )

        let result = try #require(OverviewFormatting.unpaidBreakTimeRange(
            unpaidBreak,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        ))

        #expect(result.contains("2:00"))
        #expect(result.contains("2:30"))
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
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(duration)
        )
    }
}
