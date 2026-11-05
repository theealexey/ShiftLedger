import Foundation
import Testing
@testable import ShiftLedger

struct OverviewFormattingTests {
    @Test("Displayed currency uses Decimal ties-to-even at each currency's precision",
          arguments: [
            ("EUR", "0", "0"), ("EUR", "1.004", "1"),
            ("EUR", "1.005", "1"), ("EUR", "1.015", "1.02"),
            ("EUR", "-1.005", "-1"), ("EUR", "-1.015", "-1.02"),
            ("EUR", "0.004", "0"), ("EUR", "-0.004", "0"),
            ("EUR", "9.995", "10"),
            ("EUR", "123456789012345678901234.565", "123456789012345678901234.56"),
            ("EUR", "-123456789012345678901234.565", "-123456789012345678901234.56"),
            ("EUR", "99999999999999999999999999999999999999", "99999999999999999999999999999999999999"),
            ("USD", "2.345", "2.34"),
            ("JPY", "0", "0"), ("JPY", "1.5", "2"), ("JPY", "2.5", "2"),
            ("JPY", "-1.5", "-2"), ("JPY", "0.4", "0"),
            ("JPY", "123456789012345678901234.5", "123456789012345678901234"),
            ("KWD", "0", "0"), ("KWD", "1.0004", "1"),
            ("KWD", "1.0005", "1"), ("KWD", "1.0015", "1.002"),
            ("KWD", "-1.0015", "-1.002"), ("KWD", "0.0004", "0"),
            ("KWD", "12.048", "12.048"),
            ("KWD", "123456789012345678901234.5645", "123456789012345678901234.564")
          ], ["en_US", "ru_RU", "de_CH"])
    func displayedCurrencyMatchesVisibleAmount(_ sample: (String, String, String), _ localeID: String) throws {
        let (code, source, expectedValue) = sample
        let amount = try decimal(source)
        let original = amount
        let expected = try decimal(expectedValue)
        let locale = Locale(identifier: localeID)
        #expect(OverviewFormatting.displayedCurrencyValue(amount, currencyCode: code, locale: locale) == expected)
        let visible = OverviewFormatting.currency(amount, currencyCode: code, locale: locale)
        // Preserve the previously accepted currency output, including negative displayed zero.
        #expect(visible == amount.formatted(.currency(code: code).locale(locale)))
        if amount >= .zero || expected != .zero {
            #expect(visible == expected.formatted(.currency(code: code).locale(locale)))
        }
        #expect(amount == original)
    }

    @Test("Negative sub-cent amounts retain their displayed sign without inventing a numeric amount")
    func negativeDisplayedZero() throws {
        let amount = try decimal("-0.004")
        #expect(OverviewFormatting.currency(amount, currencyCode: "EUR", locale: Locale(identifier: "en_US")) == "-€0.00")
        #expect(OverviewFormatting.displayedCurrencyValue(amount, currencyCode: "EUR", locale: locale) == .zero)
    }

    @Test("Unresolvable currency configuration and NaN fail numeric reconciliation explicitly")
    func unavailableDisplayedCurrency() {
        #expect(OverviewFormatting.displayedCurrencyValue(1, currencyCode: "INVALID", locale: locale) == nil)
        #expect(OverviewFormatting.displayedCurrencyValue(.nan, currencyCode: "EUR", locale: locale) == nil)
    }

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
        let text = try #require(OverviewFormatting.compactScheduledPeriod(weekly, timeZoneIdentifier: "UTC", locale: locale))
        #expect(text.contains("7"))
        #expect(text.contains("13"))
        #expect(text.contains("2026"))
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

    @Test("Each period endpoint retains its own date and clock", arguments: ["ru_RU", "en_US"])
    func documentPeriodHeading(_ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let ru = localeID == "ru_RU"
        for (year, month, day, duration) in [
            (2026, 11, 5, 3600), (2026, 11, 5, 48 * 3600),
            (2026, 10, 31, 24 * 3600), (2026, 12, 31, 24 * 3600),
            (2020, 11, 5, 3600)
        ] {
            let start = try date(year: year, month: month, day: day, hour: 14, minute: 43)
            let shift = try makeShift(start: start, duration: TimeInterval(duration))
            let heading = try #require(OverviewFormatting.perShiftHeading(
                shift, timeZoneIdentifier: "UTC", locale: locale))
            let end = try #require(heading.time)
            #expect(heading.date.hasPrefix(ru ? "Начало: " : "Start: "))
            #expect(end.hasPrefix(ru ? "Конец: " : "End: "))
            #expect(heading.date.contains(String(year)))
            #expect(end.contains(String(month == 12 && day == 31 ? year + 1 : year)))
            #expect(heading.date.contains(ru ? "14:43" : "2:43"))
            #expect(end.contains(duration == 3600 ? (ru ? "15:43" : "3:43") : (ru ? "14:43" : "2:43")))
            #expect(heading.accessibilityLabel == "\(heading.date); \(end)")
            #expect(shift.start == start)
            #expect(shift.end == start.addingTimeInterval(TimeInterval(duration)))
            if duration == 48 * 3600 {
                #expect(heading.date.contains("5"))
                #expect(end.contains("7"))
            }
        }
    }

    @Test("Document heading follows Job timezone and disambiguates repeated DST clocks", arguments: ["ru_RU", "en_US"])
    func documentPeriodJobTimezone(_ localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let shift = try makeShift(start: date(year: 2026, month: 11, day: 1, hour: 5, minute: 30), duration: 3600)
        let heading = try #require(OverviewFormatting.perShiftHeading(shift, timeZoneIdentifier: "America/New_York", locale: locale))
        #expect(heading.date.contains("GMT-04:00"))
        #expect(heading.time?.contains("GMT-05:00") == true)
        let midnight = try makeShift(start: date(year: 2026, month: 11, day: 5, hour: 23, minute: 30), duration: 3600)
        let local = try #require(OverviewFormatting.perShiftHeading(midnight, timeZoneIdentifier: "Europe/Stockholm", locale: locale))
        #expect(local.date.contains("6"))
        #expect(local.date.contains("2026"))
        #expect(local.date.contains( localeID == "ru_RU" ? "00:30" : "12:30"))
        #expect(local.time?.contains(localeID == "ru_RU" ? "01:30" : "1:30") == true)
    }

    @Test("Scheduled document headings retain year and inclusive calendar boundaries", arguments: ["ru_RU", "en_US"])
    func scheduledDocumentHeading(_ localeID: String) throws {
        let ru = localeID == "ru_RU"
        let locale = Locale(identifier: localeID)
        let month = PayPeriod(start: try localDate(year: 2026, month: 9, day: 1),
                              endExclusive: try localDate(year: 2026, month: 10, day: 1))
        #expect(OverviewFormatting.scheduledPeriod(month, timeZoneIdentifier: "Europe/Stockholm", locale: locale).map(normalizedPeriodSpacing)
                == (ru ? "сентябрь 2026 г." : "September 2026"))
        let week = PayPeriod(start: try localDate(year: 2026, month: 9, day: 7),
                             endExclusive: try localDate(year: 2026, month: 9, day: 14))
        #expect(OverviewFormatting.scheduledPeriod(week, timeZoneIdentifier: "Europe/Stockholm", locale: locale).map(normalizedPeriodSpacing)
                == (ru ? "7—13 сентября 2026 г." : "September 7 – 13, 2026"))
        let boundary = PayPeriod(start: try localDate(year: 2026, month: 12, day: 31),
                                 endExclusive: try localDate(year: 2027, month: 1, day: 2))
        #expect(OverviewFormatting.scheduledPeriod(boundary, timeZoneIdentifier: "Europe/Stockholm", locale: locale).map(normalizedPeriodSpacing)
                == (ru ? "31 декабря 2026 — 1 января 2027 г."
                       : "December 31, 2026 – January 1, 2027"))
        let rail = try #require(OverviewFormatting.compactScheduledPeriod(week, timeZoneIdentifier: "Europe/Stockholm", locale: locale))
        #expect(rail.contains("2026"))
    }

    // ICU may choose ordinary, thin or nonbreaking spaces on different iOS releases.
    // Keep every date/time token and separator; only normalize whitespace for comparison.
    private func normalizedPeriodSpacing(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
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

    @Test("Monthly document heading uses month and year")
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
        #expect(result == "September 2026")
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
            jobID: testJobID,
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

    @Test("Overnight time line contains only endpoint times")
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
        #expect(time == "22:43–06:43")
        #expect(time.contains("15") == false)
    }

    @Test("Multi-day time line contains only endpoint times")
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
        #expect(time == "12:56–12:56")
        #expect(time.contains("15") == false)
    }

    @Test("Date headings distinguish calendar ranges and historical years", arguments: ["ru_RU", "en_US"])
    func shiftDateRanges(_ identifier: String) throws {
        let locale = Locale(identifier: identifier)
        let reference = try date(year: 2026, month: 11, day: 1, hour: 12, minute: 0)
        let cases = [
            (2026, 10, 3, 8, "3 октября", "October 3"),
            (2026, 10, 3, 24, "3—4 октября", "October 3\u{2009}–\u{2009}4"),
            (2026, 10, 9, 48, "9—11 октября", "October 9\u{2009}–\u{2009}11"),
            (2026, 9, 30, 24, "30 сентября\u{2009}—\u{2009}1 октября", "September 30\u{2009}–\u{2009}October 1"),
            (2026, 12, 31, 24, "31 декабря 2026\u{2009}—\u{2009}1 января 2027\u{202F}г.",
             "December 31, 2026\u{2009}–\u{2009}January 1, 2027"),
            (2025, 10, 3, 8, "3 октября 2025\u{202F}г.", "October 3, 2025")
        ]
        for (year, month, day, hours, russian, english) in cases {
            let shift = try makeShift(start: date(year: year, month: month, day: day, hour: 9, minute: 0),
                                      duration: TimeInterval(hours * 3600))
            let originalStart = shift.start
            let originalEnd = shift.end
            let heading = try #require(OverviewFormatting.frontShiftDate(shift, timeZoneIdentifier: "UTC",
                locale: locale, referenceDate: reference))
            #expect(heading == (identifier == "ru_RU" ? russian : english))
            let time = try #require(OverviewFormatting.compactShiftTimeRange(shift, timeZoneIdentifier: "UTC", locale: locale))
            let endpoints = try #require(OverviewFormatting.shiftEndpoints(shift, timeZoneIdentifier: "UTC", locale: locale))
            #expect(time == "\(endpoints.startTime)–\(endpoints.endTime)")
            #expect(shift.start == originalStart && shift.end == originalEnd)
        }
    }

    @Test("Repeated DST clock times expose distinct UTC offsets", arguments: ["ru_RU", "en_US"])
    func shiftRangeAcrossDST(_ identifier: String) throws {
        let shift = try makeShift(start: date(year: 2026, month: 11, day: 1, hour: 5, minute: 30), duration: 3600)
        let locale = Locale(identifier: identifier)
        let reference = shift.start
        let heading = try #require(OverviewFormatting.frontShiftDate(shift, timeZoneIdentifier: "America/New_York", locale: locale, referenceDate: reference))
        #expect(heading == (identifier == "ru_RU" ? "1 ноября" : "November 1"))
        let endpoints = try #require(OverviewFormatting.shiftEndpoints(shift, timeZoneIdentifier: "America/New_York", locale: locale))
        #expect(endpoints.startTime == endpoints.endTime)
        #expect(endpoints.startDate == nil)
        let time = try #require(OverviewFormatting.compactShiftTimeRange(shift,
            timeZoneIdentifier: "America/New_York", locale: locale))
        let expected = identifier == "ru_RU" ? "01:30 GMT-04:00–01:30 GMT-05:00"
            : "1:30\u{202F}AM GMT-04:00–1:30\u{202F}AM GMT-05:00"
        #expect(time == expected)
        let distinctClocks = try makeShift(start: date(year: 2026, month: 11, day: 1, hour: 4, minute: 30), duration: 3 * 3600)
        let ordinary = try #require(OverviewFormatting.shiftEndpoints(distinctClocks,
            timeZoneIdentifier: "America/New_York", locale: locale))
        #expect(OverviewFormatting.compactShiftTimeRange(distinctClocks,
            timeZoneIdentifier: "America/New_York", locale: locale) == "\(ordinary.startTime)–\(ordinary.endTime)")
    }

    @Test("Cross-day accessibility retains full dates and times at both endpoints", arguments: ["ru_RU", "en_US"])
    func accessibleShiftRange(_ identifier: String) throws {
        let shift = try makeShift(start: date(year: 2026, month: 12, day: 31, hour: 22, minute: 0), duration: 8 * 3600)
        let locale = Locale(identifier: identifier)
        let result = try #require(OverviewFormatting.shiftTimeRange(shift, timeZoneIdentifier: "UTC", locale: locale))
        let expected = identifier == "ru_RU"
            ? "31.12.2026, 22:00\u{2009}—\u{2009}01.01.2027, 06:00"
            : "12/31/2026, 10:00\u{202F}PM\u{2009}–\u{2009}1/1/2027, 6:00\u{202F}AM"
        #expect(result == expected)
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

    @Test("Break date context follows Job local days, including midnight and year boundaries",
          arguments: [0, 1, 2], ["en_US", "ru_RU"])
    func unpaidBreakDateBoundaries(_ scenario: Int, _ localeID: String) throws {
        let start = try date(year: 2026, month: scenario == 2 ? 12 : 11,
                             day: scenario == 2 ? 31 : 5, hour: scenario == 2 ? 22 : 23, minute: 30)
        let end = start.addingTimeInterval(scenario == 0 ? 1800 : scenario == 1 ? 24 * 3600 : 3 * 3600)
        let unpaidBreak = UnpaidBreak(start: start, end: end)
        let locale = Locale(identifier: localeID)
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let text = try #require(OverviewFormatting.unpaidBreakTimeRange(
            unpaidBreak, timeZoneIdentifier: zone.identifier, locale: locale, includeDate: scenario == 0))
        let day = DateFormatter()
        day.locale = locale
        day.timeZone = zone
        day.dateStyle = .medium
        day.timeStyle = .none
        // UTC November 5 at 23:30 belongs to November 6 in the Job timezone.
        #expect(text.contains(day.string(from: start)))
        #expect(text.contains(day.string(from: end)))
        let expected = DateIntervalFormatter()
        expected.locale = locale
        expected.timeZone = zone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        expected.calendar = calendar
        expected.dateStyle = .medium
        expected.timeStyle = .short
        // Foundation may share AM/PM across endpoints; compare the complete interval.
        #expect(text == expected.string(from: start, to: end))
        if scenario == 2 {
            #expect(text.contains("2026") && text.contains("2027"))
        }
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
            jobID: testJobID,
            workTypeID: testWorkTypeID,
            start: start,
            end: start.addingTimeInterval(duration)
        )
    }
}
