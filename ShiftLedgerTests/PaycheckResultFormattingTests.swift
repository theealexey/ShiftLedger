import Foundation
import Testing
@testable import ShiftLedger

struct PaycheckResultFormattingTests {
    private let locale = Locale(identifier: "en_US_POSIX")

    @Test("Expected gross uses normal currency convention")
    func expectedGrossUsesCurrencyConvention() throws {
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(expected: decimal("1234.56"), actual: decimal("1200")),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(name: "Lectures")],
            locale: locale
        )

        #expect(model.expected.contains("€"))
        #expect(model.expected.contains("1234.56"))
    }

    @Test("Actual gross uses normal currency convention")
    func actualGrossUsesCurrencyConvention() throws {
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(expected: decimal("1200"), actual: decimal("1234.56")),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(name: "Lectures")],
            locale: locale
        )

        #expect(model.actual.contains("€"))
        #expect(model.actual.contains("1234.56"))
    }

    @Test("Zero difference uses conventional currency zero")
    func zeroDifferenceUsesConventionalZero() throws {
        let value = PaycheckResultFormatting.difference(
            .zero,
            currencyCode: "EUR",
            locale: locale
        )

        #expect(value == PaycheckResultFormatting.currency(.zero, currencyCode: "EUR", locale: locale))
    }

    @Test("Positive normal difference remains positive")
    func positiveDifferenceRemainsPositive() {
        let value = PaycheckResultFormatting.difference(
            Decimal(10),
            currencyCode: "EUR",
            locale: locale
        )

        #expect(value.contains("10"))
        #expect(value.contains("-") == false)
    }

    @Test("Negative normal difference remains negative")
    func negativeDifferenceRemainsNegative() {
        let value = PaycheckResultFormatting.difference(
            Decimal(-10),
            currencyCode: "EUR",
            locale: locale
        )

        #expect(value.contains("-"))
        #expect(value.contains("10"))
    }

    @Test("EUR tiny positive difference never appears as zero")
    func tinyPositiveDifferenceIsVisible() throws {
        let amount = try decimal("0.004")
        let value = PaycheckResultFormatting.difference(amount, currencyCode: "EUR", locale: locale)
        let zero = PaycheckResultFormatting.difference(.zero, currencyCode: "EUR", locale: locale)

        #expect(value != zero)
        #expect(value.contains("004"))
    }

    @Test("EUR tiny negative difference never appears as zero")
    func tinyNegativeDifferenceIsVisible() throws {
        let amount = try decimal("-0.004")
        let value = PaycheckResultFormatting.difference(amount, currencyCode: "EUR", locale: locale)
        let zero = PaycheckResultFormatting.difference(.zero, currencyCode: "EUR", locale: locale)

        #expect(value != zero)
        #expect(value.contains("-"))
        #expect(value.contains("004"))
    }

    @Test("Tiny difference retains direction")
    func tinyDifferenceRetainsDirection() throws {
        let positive = PaycheckResultFormatting.difference(
            try decimal("0.000001"),
            currencyCode: "EUR",
            locale: locale
        )
        let negative = PaycheckResultFormatting.difference(
            try decimal("-0.000001"),
            currencyCode: "EUR",
            locale: locale
        )

        #expect(positive.contains("-") == false)
        #expect(negative.contains("-"))
        #expect(positive != negative)
    }

    @Test("JPY fractional non-zero difference remains visible")
    func jpyFractionalDifferenceIsVisible() throws {
        let amount = try decimal("0.4")
        let value = PaycheckResultFormatting.difference(amount, currencyCode: "JPY", locale: locale)
        let zero = PaycheckResultFormatting.difference(.zero, currencyCode: "JPY", locale: locale)

        #expect(value != zero)
        #expect(value.contains(".4"))
    }

    @Test("Currency formatting does not impose two fraction digits")
    func currencyFormattingUsesCurrencyFractionConvention() {
        let value = PaycheckResultFormatting.currency(
            Decimal(1_234),
            currencyCode: "JPY",
            locale: locale
        )

        #expect(value.contains(".00") == false)
    }

    @Test("Formatting leaves the source Decimal unchanged")
    func formattingPreservesDecimal() throws {
        let amount = try decimal("1234.56789")
        let original = amount

        _ = PaycheckResultFormatting.difference(amount, currencyCode: "EUR", locale: locale)

        #expect(amount == original)
    }

    @Test("Negative difference maps to neutral lower copy")
    func negativeDifferenceUsesLowerCopy() {
        #expect(PaycheckResultFormatting.explanation(for: -1) == PaycheckResultStrings.lower)
    }

    @Test("Zero difference maps to exact-equality copy")
    func zeroDifferenceUsesEqualCopy() {
        #expect(PaycheckResultFormatting.explanation(for: .zero) == PaycheckResultStrings.equal)
    }

    @Test("Positive difference maps to neutral higher copy")
    func positiveDifferenceUsesHigherCopy() {
        #expect(PaycheckResultFormatting.explanation(for: 1) == PaycheckResultStrings.higher)
    }

    @Test("Same-day Shift renders in the supplied Job timezone")
    func sameDayShiftUsesJobTimeZone() throws {
        let shift = try makeShift(
            start: date(timeZone: "Europe/Stockholm", day: 20, hour: 8),
            end: date(timeZone: "Europe/Stockholm", day: 20, hour: 16)
        )

        let value = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        )

        #expect(value.contains("Sep"))
        #expect(value.contains("20"))
        #expect(value.contains("8:00"))
        #expect(value.contains("4:00"))
    }

    @Test("Overnight Shift displays both local dates")
    func overnightShiftDisplaysBothDates() throws {
        let shift = try makeShift(
            start: date(timeZone: "Europe/Stockholm", day: 20, hour: 22),
            end: date(timeZone: "Europe/Stockholm", day: 21, hour: 6)
        )

        let value = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        )

        #expect(value.contains("20"))
        #expect(value.contains("21"))
        #expect(value.contains("10:00"))
        #expect(value.contains("6:00"))
    }

    @Test("Same absolute Shift renders differently for supplied timezones")
    func sameShiftUsesSuppliedTimeZone() throws {
        let shift = try makeShift(
            start: date(timeZone: "UTC", day: 20, hour: 22),
            end: date(timeZone: "UTC", day: 21, hour: 6)
        )

        let utc = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "UTC",
            locale: locale
        )
        let stockholm = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "Europe/Stockholm",
            locale: locale
        )

        #expect(utc != stockholm)
        #expect(utc.contains("10:00"))
        #expect(stockholm.contains("12:00"))
    }

    @Test("Shift formatting is stable for an explicit timezone")
    func shiftFormattingDoesNotDependOnDeviceTimeZone() throws {
        let shift = try makeShift(
            start: date(timeZone: "UTC", day: 20, hour: 0),
            end: date(timeZone: "UTC", day: 20, hour: 8)
        )

        let first = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "America/New_York",
            locale: locale
        )
        let second = PaycheckResultFormatting.shiftDateTime(
            shift,
            timeZoneIdentifier: "America/New_York",
            locale: locale
        )

        #expect(first == second)
        #expect(first.contains("Sep"))
        #expect(first.contains("19"))
    }

    @Test("Whole hours render without empty components")
    func wholeHoursRender() {
        #expect(PaycheckResultFormatting.paidDuration(8 * 3_600) == "8 \(PaycheckResultStrings.durationHour)")
    }

    @Test("Hours and minutes both render")
    func hoursAndMinutesRender() {
        let expected = "7 \(PaycheckResultStrings.durationHour) 30 \(PaycheckResultStrings.durationMinute)"
        #expect(PaycheckResultFormatting.paidDuration(7.5 * 3_600) == expected)
    }

    @Test("Minutes render without a zero-hour prefix")
    func minutesOnlyRender() {
        #expect(PaycheckResultFormatting.paidDuration(45 * 60) == "45 \(PaycheckResultStrings.durationMinute)")
    }

    @Test("Whole seconds render without fractional precision")
    func wholeSecondsRender() {
        #expect(PaycheckResultFormatting.paidDuration(15) == "15 \(PaycheckResultStrings.durationSecond)")
    }

    @Test("Non-zero seconds are not silently removed")
    func secondsRender() {
        let expected = "7 \(PaycheckResultStrings.durationHour) "
            + "30 \(PaycheckResultStrings.durationMinute) "
            + "15 \(PaycheckResultStrings.durationSecond)"
        #expect(PaycheckResultFormatting.paidDuration(7 * 3_600 + 30 * 60 + 15) == expected)
    }

    @Test("Runtime fractional-second regression rounds to a human-readable second")
    func runtimeFractionalSecondRegressionRoundsForDisplay() {
        let value = PaycheckResultFormatting.paidDuration(54.974985003471375)

        #expect(value == "55 \(PaycheckResultStrings.durationSecond)")
        #expect(value.contains("54.974985") == false)
    }

    @Test("Seconds carry into minutes after presentation rounding")
    func roundedSecondsCarryIntoMinutes() {
        #expect(PaycheckResultFormatting.paidDuration(59.6) == "1 \(PaycheckResultStrings.durationMinute)")
        #expect(PaycheckResultFormatting.paidDuration(60) == "1 \(PaycheckResultStrings.durationMinute)")
    }

    @Test("Rounded duration preserves hours minutes and seconds")
    func roundedDurationPreservesComponents() {
        let expected = "7 \(PaycheckResultStrings.durationHour) "
            + "30 \(PaycheckResultStrings.durationMinute) "
            + "15 \(PaycheckResultStrings.durationSecond)"

        #expect(PaycheckResultFormatting.paidDuration(7 * 3_600 + 30 * 60 + 15.4) == expected)
    }

    @Test("Positive duration below half a second uses a complete localized phrase")
    func subSecondDurationUsesLocalizedPhrase() {
        #expect(PaycheckResultFormatting.paidDuration(0.4) == PaycheckResultStrings.durationLessThanSecond)
    }

    @Test("Hourly rate exposes per-hour semantics")
    func hourlyRateUsesHourUnit() {
        let value = PaycheckResultFormatting.rate(
            amount: Decimal(20),
            basis: .hourly,
            currencyCode: "EUR",
            locale: locale
        )

        #expect(value.contains("/ \(PaycheckResultStrings.rateHour)"))
    }

    @Test("Fixed rate exposes per-shift semantics")
    func fixedRateUsesShiftUnit() {
        let value = PaycheckResultFormatting.rate(
            amount: Decimal(120),
            basis: .fixedPerShift,
            currencyCode: "EUR",
            locale: locale
        )

        #expect(value.contains("/ \(PaycheckResultStrings.rateShift)"))
    }

    @Test("Rate formatting follows supplied currency convention")
    func rateUsesCurrencyConvention() {
        let value = PaycheckResultFormatting.rate(
            amount: Decimal(1_234),
            basis: .hourly,
            currencyCode: "JPY",
            locale: locale
        )

        #expect(value.contains("¥"))
        #expect(value.contains(".00") == false)
    }

    @Test("Breakdown uses the matching WorkType's exact name")
    func namedWorkTypeIsRendered() throws {
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(expected: 160, actual: 150, breakdowns: [breakdown()]),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(name: "Lectures")],
            locale: locale
        )

        #expect(model.breakdownRows.first?.workTypeName == "Lectures")
    }

    @Test("Unnamed WorkType uses the localized presentation fallback")
    func unnamedWorkTypeUsesFallback() throws {
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(expected: 160, actual: 150, breakdowns: [breakdown()]),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(name: nil)],
            locale: locale
        )

        #expect(model.breakdownRows.first?.workTypeName == PaycheckResultStrings.unnamedWorkType)
    }

    @Test("A missing WorkType lookup remains safe")
    func missingWorkTypeUsesFallback() throws {
        let differentID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000099"))
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(expected: 160, actual: 150, breakdowns: [breakdown()]),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [try workType(id: differentID, name: "Exams")],
            locale: locale
        )

        #expect(model.breakdownRows.first?.workTypeName == PaycheckResultStrings.unnamedWorkType)
    }

    private func breakdown() throws -> ShiftPayBreakdown {
        let rate = try PayRate(amount: 20, effectiveFrom: nil)
        return ShiftPayBreakdown(
            shift: try makeShift(
                start: date(timeZone: "Europe/Stockholm", day: 20, hour: 8),
                end: date(timeZone: "Europe/Stockholm", day: 20, hour: 16)
            ),
            basePayBasis: .hourly,
            appliedPayRate: rate,
            paidDuration: 8 * 3_600,
            basePay: 160
        )
    }

    private func workType(id: UUID = testWorkTypeID, name: String?) throws -> WorkType {
        WorkType(
            id: id,
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [PayRate(amount: 20, effectiveFrom: nil)])
        )
    }

    private func comparison(
        expected: Decimal,
        actual: Decimal,
        breakdowns: [ShiftPayBreakdown] = []
    ) throws -> PaycheckComparison {
        let shiftID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        return PaycheckComparison(
            expected: ExpectedGrossBreakdown(
                period: .perShift(shiftID: shiftID),
                shiftBreakdowns: breakdowns,
                expectedGross: expected
            ),
            actualGross: try ActualGross(amount: actual)
        )
    }

    private func makeShift(start: Date, end: Date) throws -> Shift {
        try Shift(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000010")),
            workTypeID: testWorkTypeID,
            start: start,
            end: end
        )
    }

    private func date(timeZone identifier: String, day: Int, hour: Int) throws -> Date {
        let timeZone = try #require(TimeZone(identifier: identifier))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: day,
            hour: hour
        )))
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value, locale: locale))
    }
}
