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

        #expect(model.expectedAmount.text.contains("€"))
        #expect(model.expectedAmount.text.contains("1234.56"))
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

        #expect(model.actualAmount.text.contains("€"))
        #expect(model.actualAmount.text.contains("1234.56"))
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

    @Test("Exact zero preserves locale currency spacing and has no approximation",
          arguments: ["EUR", "SEK", "JPY"], ["en_US_POSIX", "en_US", "ru_RU"])
    func exactZeroPreservesCurrencyConvention(code: String, identifier: String) throws {
        let displayLocale = Locale(identifier: identifier)
        let source = try comparison(expected: .zero, actual: .zero, breakdowns: [])
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: code, timeZoneIdentifier: "UTC", workTypes: [], locale: displayLocale
        )
        let standard = PaycheckResultFormatting.currency(.zero, currencyCode: code, locale: displayLocale)
        #expect(PaycheckResultFormatting.difference(.zero, currencyCode: code, locale: displayLocale) == standard)
        #expect(model.expected == standard)
        #expect(model.actual == standard)
        #expect(model.difference == standard)
        #expect(!model.differenceAmount.isBound && !model.differenceAmount.isApproximate)
        #expect(model.approximationNote == nil)
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
        #expect(value.contains("<"))
        #expect(value.contains("0.01"))
    }

    @Test("EUR tiny negative difference never appears as zero")
    func tinyNegativeDifferenceIsVisible() throws {
        let amount = try decimal("-0.004")
        let value = PaycheckResultFormatting.difference(amount, currencyCode: "EUR", locale: locale)
        let zero = PaycheckResultFormatting.difference(.zero, currencyCode: "EUR", locale: locale)

        #expect(value != zero)
        #expect(value.contains("-"))
        #expect(value.contains("<"))
        #expect(value.contains("0.01"))
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
        #expect(value.contains("<"))
        #expect(value.contains("1"))
        #expect(value.contains(".") == false)
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

    @Test("Ordinary results respect each currency's minor units", arguments: ["EUR", "SEK", "JPY", "KWD"])
    func ordinaryResultsReconcile(_ code: String) throws {
        let model = try result(rows: ["10", "20"], actual: "35", currencyCode: code)
        #expect(displayedAmount(model.expectedAmount.text) == 30)
        #expect(displayedAmount(model.actualAmount.text) == 35)
        #expect(displayedAmount(model.differenceAmount.text) == 5)
        #expect(model.differenceAmount.text.hasPrefix("+"))
        #expect(!model.expectedAmount.needsExactDetail && !model.differenceAmount.needsExactDetail)
        #expect(model.approximationNote == nil)
    }

    @Test("Exactly one minor unit is displayed as an exact, ordinary difference",
          arguments: [("JPY", "1"), ("EUR", "0.01"), ("SEK", "0.01"), ("KWD", "0.001")])
    func oneMinorUnit(code: String, unit: String) throws {
        let model = try result(rows: ["0"], actual: unit, currencyCode: code)
        #expect(!model.differenceAmount.needsExactDetail)
        #expect(model.differenceAmount.text.hasPrefix("+"))
        #expect(try displayedAmount(model.differenceAmount.text) == decimal(unit))
    }

    @Test("Sub-minor differences have a localized bound, accessible direction and full exact value",
          arguments: ["en_US", "ru_RU"])
    func tinyDifferencePresentation(_ identifier: String) throws {
        let displayLocale = Locale(identifier: identifier)
        let positive = try result(rows: ["2.008"], actual: "2.010", currencyCode: "SEK", displayLocale: displayLocale)
        let negative = try result(rows: ["2.010"], actual: "2.008", currencyCode: "SEK", displayLocale: displayLocale)
        let zero = try result(rows: ["2.008"], actual: "2.008", currencyCode: "SEK", displayLocale: displayLocale)
        let threshold = identifier == "ru_RU" ? "0,01" : "0.01"

        #expect(positive.differenceAmount.text.hasPrefix("+<"))
        #expect(negative.differenceAmount.text.hasPrefix("-<"))
        #expect(positive.differenceAmount.text.contains(threshold))
        #expect(negative.differenceAmount.text.contains(threshold))
        #expect(positive.differenceAmount.accessibilityText != negative.differenceAmount.accessibilityText)
        #expect(!positive.differenceAmount.accessibilityText.contains("<"))
        #expect(!negative.differenceAmount.accessibilityText.contains("<"))
        #expect(positive.differenceAmount.accessibilityText.contains(threshold))
        #expect(negative.differenceAmount.accessibilityText.contains(threshold))
        #expect(positive.differenceAmount.isBound && negative.differenceAmount.isBound)
        #expect(zero.differenceAmount.text.contains("<") == false)
        #expect(zero.differenceAmount.needsExactDetail == false)
        #expect(positive.differenceAmount.exact == (identifier == "ru_RU" ? "+0,002 SEK" : "+0.002 SEK"))
        #expect(negative.differenceAmount.exact == (identifier == "ru_RU" ? "-0,002 SEK" : "-0.002 SEK"))
    }

    @Test("Approximate rows and totals can differ while their exact values reconcile",
          arguments: [
            (["1.004", "1.004"], "2.008", "2.01"),
            (["1.005", "1.005"], "2.01", "2.01"),
            (["1.004", "2.006"], "3.01", "3.01"),
            (["1.004", "1.004"], "2.010", "2.01"),
            (["0.0004", "0.0004", "0.0004", "0.0004"], "0.0016", "0.01"),
            (["0.004", "0.004", "0.004"], "0.012", "0.01"),
            (["10", "0.0004"], "10.0004", "10.00")
          ])
    func roundedSummaryPreservesExactEvidence(rows: [String], actual: String, display: String) throws {
        let model = try result(rows: rows, actual: actual)
        #expect(try displayedAmount(model.expectedAmount.text) == decimal(display))
        #expect(model.breakdownRows.allSatisfy { $0.amount.needsExactDetail }
            || rows.contains("10"))
        #expect(model.approximationNote != nil || model.expectedAmount.isBound)
        let expected = try rows.map(decimal).reduce(.zero, +)
        if try expected >= 0.01 && expected != decimal(display) {
            #expect(model.expectedAmount.text.hasPrefix("≈"))
            #expect(model.expectedAmount.accessibilityText != model.expectedAmount.text)
        }
    }

    @Test("JPY fractions remain distinguishable from zero without adding fractional yen to the summary")
    func fractionalJPY() throws {
        let model = try result(rows: ["1.4", "1.4"], actual: "3.0", currencyCode: "JPY")
        #expect(model.expectedAmount.text.hasPrefix("≈"))
        #expect(displayedAmount(model.expectedAmount.text) == 3)
        #expect(model.differenceAmount.text.hasPrefix("+<"))
        #expect(model.differenceAmount.exact == "+0.2 JPY")
    }

    @Test("Exact rate and contribution preserve hourly and fixed-shift arithmetic",
          arguments: [BasePayBasis.hourly, .fixedPerShift])
    func exactRatesReconcile(_ basis: BasePayBasis) throws {
        let rate = try decimal("1.004")
        let expected = basis == .hourly ? rate * 8 : rate
        let source = try comparison(
            expected: expected, actual: expected + decimal("0.002"),
            breakdowns: [breakdown(amount: expected, rateAmount: rate, basis: basis)]
        )
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: "EUR", timeZoneIdentifier: "UTC", workTypes: [], locale: locale
        )
        let row = try #require(model.breakdownRows.first)
        #expect(row.rate.text.hasPrefix("≈"))
        #expect(row.rate.exact.hasSuffix(basis == .hourly
            ? PaycheckResultStrings.rateHour : PaycheckResultStrings.rateShift))
        let exactRate = try #require(displayedAmount(row.rate.exact.components(separatedBy: " / ")[0]))
        #expect(exactRate == rate)
        #expect(try exactAmount(row.amount.exact) == (basis == .hourly ? exactRate * 8 : exactRate))
        #expect(row.duration == PaycheckResultFormatting.paidDuration(8 * 3_600))
        try expectExact(model, comparison: source, displayLocale: locale)
    }

    @Test("Scheduled empty breakdown preserves zero and shows a nonzero bound for fractional actual")
    func scheduledZeroBreakdownRemainsExplainable() throws {
        let source = PaycheckComparison(
            expected: ExpectedGrossBreakdown(
                period: .scheduled(PayPeriod(
                    start: try LocalDate(year: 2026, month: 9, day: 1),
                    endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
                )),
                shiftBreakdowns: [], expectedGross: .zero
            ),
            actualGross: try ActualGross(amount: decimal("0.0004"))
        )
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [], locale: locale
        )
        #expect(model.breakdownRows.isEmpty)
        #expect(model.emptyBreakdownMessage == PaycheckResultStrings.breakdownEmpty)
        #expect(!model.expectedAmount.needsExactDetail)
        #expect(model.actualAmount.isBound && model.differenceAmount.isBound)
        try expectExact(model, comparison: source, displayLocale: locale)
    }

    @Test("Long fractional amounts preserve all original digits and leave Domain values unchanged",
          arguments: ["en_US", "ru_RU"])
    func minuteShiftPrecision(_ identifier: String) throws {
        let locale = Locale(identifier: identifier)
        let expected = try decimal("1.6666666666666666666666666666666666666")
        let actual = try decimal("1.666666666667")
        let source = try comparison(expected: expected, actual: actual, breakdowns: [breakdown(amount: expected, rateAmount: 100)])
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: "SEK", timeZoneIdentifier: "UTC", workTypes: [], locale: locale
        )
        #expect(model.expectedAmount.text.contains(identifier == "ru_RU" ? "1,67" : "1.67"))
        #expect(model.expectedAmount.text.hasPrefix("≈") && model.actualAmount.text.hasPrefix("≈"))
        #expect(model.differenceAmount.text.hasPrefix("+<"))
        #expect(model.differenceAmount.text.count < 14)
        #expect(source.expected.expectedGross == expected && source.actualGross.amount == actual)
        try expectExact(model, comparison: source, displayLocale: locale)
    }

    @Test("Extreme Decimal magnitude and very small scale retain original evidence",
          arguments: ["1e100", "12345678901234567890123456789012345678", "1e-40"])
    func extremeMagnitudeRemainsExact(_ value: String) throws {
        let model = try result(rows: [value], actual: "0")
        #expect(model.expectedAmount.text.count < 20)
        #expect(model.differenceAmount.text.count < 20)
        #expect(model.expectedAmount.needsExactDetail && model.differenceAmount.needsExactDetail)
        #expect(try exactAmount(model.expectedAmount.exact) == decimal(value))
        #expect(try exactAmount(model.differenceAmount.exact) == -decimal(value))
    }

    private func result(
        rows: [String], actual: String, currencyCode: String = "EUR", displayLocale: Locale? = nil
    ) throws -> PaycheckResultView.RenderModel {
        let amounts = try rows.map(decimal)
        let breakdowns = try amounts.map { try breakdown(amount: $0) }
        let source = try comparison(expected: amounts.reduce(.zero, +), actual: decimal(actual), breakdowns: breakdowns)
        let displayLocale = displayLocale ?? locale
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: currencyCode, timeZoneIdentifier: "UTC", workTypes: [], locale: displayLocale
        )
        try expectExact(model, comparison: source, displayLocale: displayLocale)
        return model
    }

    private func expectExact(_ model: PaycheckResultView.RenderModel, comparison: PaycheckComparison,
                             displayLocale: Locale) throws {
        let expected = try exactAmount(model.expectedAmount.exact, locale: displayLocale)
        let actual = try exactAmount(model.actualAmount.exact, locale: displayLocale)
        let difference = try exactAmount(model.differenceAmount.exact, locale: displayLocale)
        let rows = try model.breakdownRows.map { try exactAmount($0.amount.exact, locale: displayLocale) }
        #expect(expected == comparison.expected.expectedGross)
        #expect(actual == comparison.actualGross.amount)
        #expect(difference == comparison.difference)
        #expect(rows == comparison.expected.shiftBreakdowns.map(\.basePay))
        #expect(rows.reduce(.zero, +) == expected)
        #expect(actual - expected == difference)
        for (breakdown, row) in zip(comparison.expected.shiftBreakdowns, model.breakdownRows) {
            let amount = try #require(row.rate.exact.components(separatedBy: " / ").first)
            #expect(try exactAmount(amount, locale: displayLocale) == breakdown.appliedPayRate.amount)
        }
    }

    private func exactAmount(_ text: String, locale: Locale? = nil) throws -> Decimal {
        let number = try #require(text.split(separator: " ").first)
        return try #require(Decimal(string: String(number), locale: locale ?? self.locale))
    }

    private func displayedAmount(_ text: String) -> Decimal? {
        Decimal(string: text.filter { $0.isNumber || $0 == "." || $0 == "-" }, locale: locale)
    }

    private func breakdown(
        amount: Decimal = 160, rateAmount: Decimal = 20, basis: BasePayBasis = .hourly
    ) throws -> ShiftPayBreakdown {
        let rate = try PayRate(amount: rateAmount, effectiveFrom: nil)
        return ShiftPayBreakdown(
            shift: try makeShift(
                start: date(timeZone: "Europe/Stockholm", day: 20, hour: 8),
                end: date(timeZone: "Europe/Stockholm", day: 20, hour: 16)
            ),
            basePayBasis: basis,
            appliedPayRate: rate,
            paidDuration: 8 * 3_600,
            basePay: amount
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
        breakdowns: [ShiftPayBreakdown]? = nil
    ) throws -> PaycheckComparison {
        let shiftID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        return PaycheckComparison(
            expected: ExpectedGrossBreakdown(
                period: .perShift(shiftID: shiftID),
                shiftBreakdowns: try breakdowns ?? [breakdown(amount: expected)],
                expectedGross: expected
            ),
            actualGross: try ActualGross(amount: actual)
        )
    }

    private func makeShift(start: Date, end: Date) throws -> Shift {
        try Shift(
            id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000010")),
            jobID: testJobID,
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
