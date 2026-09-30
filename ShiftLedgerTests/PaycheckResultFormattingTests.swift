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

    @Test("Ordinary EUR and JPY Results retain currency precision and reconcile")
    func ordinaryResultsReconcile() throws {
        for code in ["EUR", "JPY"] {
            let model = try result(rows: ["10", "20"], actual: "35", currencyCode: code)
            try expectReconciled(model, locale: locale)
            #expect(model.expected == PaycheckResultFormatting.currency(30, currencyCode: code, locale: locale))
            #expect(model.actual == PaycheckResultFormatting.currency(35, currencyCode: code, locale: locale))
            #expect(model.difference.hasPrefix("+"))
        }
    }

    @Test("Sub-minor breakdown amounts reveal the lowest reconciling precision")
    func subMinorBreakdownReconciles() throws {
        let model = try result(rows: ["1.004", "1.004"], actual: "2.008")
        try expectReconciled(model, locale: locale)
        #expect(try displayedAmount(model.expected, locale: locale) == decimal("2.008"))
        #expect(model.breakdownRows.map(\.amount) == [try money("1.004", digits: 3), try money("1.004", digits: 3)])
        try expectMoney(model.difference, "0", digits: 3)
    }

    @Test("Half-even boundary rounding cannot contradict the breakdown sum")
    func roundingBoundaryReconciles() throws {
        let model = try result(rows: ["1.005", "1.005"], actual: "2.01")
        try expectReconciled(model, locale: locale)
        #expect(try displayedAmount(model.expected, locale: locale) == decimal("2.01"))
        #expect(model.breakdownRows.map(\.amount) == [try money("1.005", digits: 3), try money("1.005", digits: 3)])
        try expectMoney(model.actual, "2.010", digits: 3)
    }

    @Test("Mixed sub-minor values do not increase precision when normal rounding reconciles")
    func mixedValuesKeepNormalPrecision() throws {
        let model = try result(rows: ["1.004", "2.006"], actual: "3.01")
        try expectReconciled(model, locale: locale)
        #expect(model.breakdownRows.map(\.amount) == [try money("1.00", digits: 2), try money("2.01", digits: 2)])
        try expectMoney(model.expected, "3.01", digits: 2)
        try expectMoney(model.difference, "0", digits: 2)
    }

    @Test("Summary subtraction and every breakdown row share three fraction digits")
    func summaryUsesCoherentPrecision() throws {
        let model = try result(rows: ["1.004", "1.004"], actual: "2.010")
        try expectReconciled(model, locale: locale)
        try expectMoney(model.expected, "2.008", digits: 3)
        try expectMoney(model.actual, "2.010", digits: 3)
        let positiveDifference = try money("0.002", digits: 3, signed: true)
        #expect(model.difference == positiveDifference)
    }

    @Test("Tiny negative difference remains explained by the displayed summary")
    func negativeSummaryReconciles() throws {
        let model = try result(rows: ["2.010"], actual: "2.008")
        try expectReconciled(model, locale: locale)
        try expectMoney(model.expected, "2.010", digits: 3)
        try expectMoney(model.actual, "2.008", digits: 3)
        #expect(try displayedAmount(model.difference, locale: locale) == decimal("-0.002"))
    }

    @Test("Exact zero summary retains conventional zero when the breakdown reconciles")
    func exactZeroKeepsNormalPrecision() throws {
        let model = try result(rows: ["1.00", "2.00"], actual: "3.00")
        try expectReconciled(model, locale: locale)
        try expectMoney(model.difference, "0", digits: 2)
        try expectMoney(model.expected, "3", digits: 2)
    }

    @Test("JPY fractions use extra precision only to preserve real arithmetic")
    func fractionalJPYReconciles() throws {
        let normal = try result(rows: ["1.2", "1.2"], actual: "2.4", currencyCode: "JPY")
        try expectReconciled(normal, locale: locale)
        #expect(normal.expected.contains(".") == false)
        let extra = try result(rows: ["1.4", "1.4"], actual: "3.0", currencyCode: "JPY")
        try expectReconciled(extra, locale: locale)
        #expect(try displayedAmount(extra.expected, locale: locale) == decimal("2.8"))
        #expect(try displayedAmount(extra.difference, locale: locale) == decimal("0.2"))
        #expect(extra.actual.hasSuffix("3.0"))
    }

    @Test("Many rows reconcile at the minimal precision, not an arbitrary fixed scale")
    func multipleRowsReconcile() throws {
        let model = try result(rows: ["0.0004", "0.0004", "0.0004", "0.0004"], actual: "0.0016")
        try expectReconciled(model, locale: locale)
        try expectMoney(model.expected, "0.0016", digits: 4)
        try expectMoney(model.actual, "0.0016", digits: 4)
        try expectMoney(model.difference, "0", digits: 4)
        let visibleRow = try money("0.0004", digits: 4)
        #expect(model.breakdownRows.map(\.amount) == Array(repeating: visibleRow, count: 4))
        let nonzero = try result(rows: ["0.004", "0.004", "0.004"], actual: "0.012")
        try expectReconciled(nonzero, locale: locale)
        try expectMoney(nonzero.expected, "0.012", digits: 3)
    }

    @Test("A tiny non-zero row stays visible even when the summary is much larger")
    func tinyRowNeverDisappears() throws {
        let model = try result(rows: ["10", "0.0004"], actual: "10.0004")
        try expectReconciled(model, locale: locale)
        try expectMoney(model.expected, "10.0004", digits: 4)
        let row = try #require(model.breakdownRows.last)
        try expectMoney(row.amount, "0.0004", digits: 4)
    }

    @Test("Fixed-per-shift rate equals its amount in the shared expanded precision")
    func fixedRateMatchesAdaptiveAmount() throws {
        let amount = try decimal("1.004")
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(
                expected: amount, actual: decimal("1.006"),
                breakdowns: [breakdown(amount: amount, rateAmount: amount, basis: .fixedPerShift)]
            ),
            currencyCode: "EUR", timeZoneIdentifier: "UTC", workTypes: [], locale: locale
        )
        try expectReconciled(model, locale: locale)
        let row = try #require(model.breakdownRows.first)
        try expectMoney(row.amount, "1.004", digits: 3)
        #expect(row.rate == "\(row.amount) / \(PaycheckResultStrings.rateShift)")
        #expect(try displayedAmount(rateAmount(row.rate), locale: locale) == amount)
    }

    @Test("Hourly rate shares Result precision without changing paid-duration semantics")
    func hourlyRateSharesAdaptivePrecision() throws {
        let rate = try decimal("1.004")
        let expected = rate * 8
        let model = PaycheckResultFormatting.renderModel(
            comparison: try comparison(
                expected: expected, actual: expected + decimal("0.002"),
                breakdowns: [breakdown(amount: expected, rateAmount: rate)]
            ),
            currencyCode: "EUR", timeZoneIdentifier: "UTC", workTypes: [], locale: locale
        )
        try expectReconciled(model, locale: locale)
        let row = try #require(model.breakdownRows.first)
        let formattedRate = try money("1.004", digits: 3)
        #expect(row.rate == "\(formattedRate) / \(PaycheckResultStrings.rateHour)")
        #expect(row.duration == PaycheckResultFormatting.paidDuration(8 * 3_600))
        #expect(try displayedAmount(rateAmount(row.rate), locale: locale) * 8
            == displayedAmount(row.amount, locale: locale))
    }

    @Test("Scheduled empty breakdown preserves non-zero Actual and Difference")
    func scheduledZeroBreakdownRemainsExplainable() throws {
        let actual = try decimal("0.0004")
        let source = PaycheckComparison(
            expected: ExpectedGrossBreakdown(
                period: .scheduled(PayPeriod(
                    start: try LocalDate(year: 2026, month: 9, day: 1),
                    endExclusive: try LocalDate(year: 2026, month: 10, day: 1)
                )),
                shiftBreakdowns: [], expectedGross: .zero
            ),
            actualGross: try ActualGross(amount: actual)
        )
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: "EUR", timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [], locale: locale
        )
        try expectReconciled(model, locale: locale)
        #expect(model.breakdownRows.isEmpty)
        #expect(model.emptyBreakdownMessage == PaycheckResultStrings.breakdownEmpty)
        try expectMoney(model.expected, "0", digits: 4)
        try expectMoney(model.actual, "0.0004", digits: 4)
        let signedActual = try money("0.0004", digits: 4, signed: true)
        #expect(model.difference == signedActual)
        #expect(try displayedAmount(model.actual, locale: locale) == actual)
        #expect(try displayedAmount(model.difference, locale: locale) == actual)
    }

    @Test("Difference signs use localized formatter affixes at shared precision")
    func differenceUsesLocaleSignAffixes() throws {
        for identifier in ["en_US_POSIX", "de_DE", "ru_RU"] {
            let displayLocale = Locale(identifier: identifier)
            let positive = try result(rows: ["2.008"], actual: "2.010", displayLocale: displayLocale)
            let negative = try result(rows: ["2.008"], actual: "2.006", displayLocale: displayLocale)
            try expectReconciled(positive, locale: displayLocale)
            try expectReconciled(negative, locale: displayLocale)
            let positiveText = try money("0.002", digits: 3, signed: true, displayLocale: displayLocale)
            let negativeText = try money("-0.002", digits: 3, signed: true, displayLocale: displayLocale)
            #expect(positive.difference == positiveText)
            #expect(negative.difference == negativeText)
        }
    }

    @Test("Rendering never mutates Domain Decimal inputs")
    func renderingPreservesSourceValues() throws {
        let rows = try [breakdown(amount: decimal("1.004")), breakdown(amount: decimal("1.004"))]
        let source = try comparison(expected: decimal("2.008"), actual: decimal("2.010"), breakdowns: rows)
        let expected = source.expected.expectedGross
        let actual = source.actualGross.amount
        let difference = source.difference
        let amounts = source.expected.shiftBreakdowns.map(\.basePay)
        _ = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: "EUR", timeZoneIdentifier: "UTC", workTypes: [], locale: locale
        )
        #expect(source.expected.expectedGross == expected)
        #expect(source.actualGross.amount == actual)
        #expect(source.difference == difference)
        #expect(source.expected.shiftBreakdowns.map(\.basePay) == amounts)
    }

    @Test("Currency placement and separators remain locale-owned at additional precision")
    func additionalPrecisionUsesLocale() throws {
        let german = Locale(identifier: "de_DE")
        let model = try result(rows: ["1.004", "1.004"], actual: "2.010", displayLocale: german)
        try expectReconciled(model, locale: german)
        let formatter = NumberFormatter()
        formatter.locale = german
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.roundingMode = .halfEven
        #expect(model.actual == formatter.string(from: NSDecimalNumber(decimal: try decimal("2.010"))))
        #expect(model.expected.contains("2,008"))
    }

    @Test("Extreme Decimal magnitude remains arithmetically explainable without digit loss")
    func extremeMagnitudeRemainsExact() throws {
        let huge = "1e100"
        let model = try result(rows: [huge], actual: "0")
        try expectReconciled(model, locale: locale)
        #expect(model.difference.hasPrefix("-"))
        #expect(try displayedAmount(model.actual, locale: locale) == .zero)
        #expect(try displayedAmount(model.expected, locale: locale) == decimal(huge))
    }

    @Test("Representable tiny Decimals remain visible beyond 38 fractional places")
    func tinyDecimalScaleRemainsVisible() throws {
        let tiny = "0.0000000000000000000000000000000000000001"
        let model = try result(rows: [tiny], actual: "0")
        try expectReconciled(model, locale: locale)
        #expect(try displayedAmount(model.expected, locale: locale) == decimal(tiny))
        #expect(try displayedAmount(model.difference, locale: locale) == -decimal(tiny))
    }

    private func money(
        _ value: String, digits: Int, signed: Bool = false, displayLocale: Locale? = nil
    ) throws -> String {
        let formatter = NumberFormatter()
        formatter.locale = displayLocale ?? locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.roundingMode = .halfEven
        let amount = try decimal(value)
        if signed, amount > .zero {
            formatter.positivePrefix = "+" + (formatter.positivePrefix ?? "")
        }
        return try #require(formatter.string(from: NSDecimalNumber(decimal: amount)))
    }

    private func expectMoney(_ text: String, _ value: String, digits: Int) throws {
        let expected = try money(value, digits: digits)
        #expect(text == expected)
    }

    private func result(
        rows: [String], actual: String, currencyCode: String = "EUR", displayLocale: Locale? = nil
    ) throws -> PaycheckResultView.RenderModel {
        let amounts = try rows.map(decimal)
        let breakdowns = try amounts.map { try breakdown(amount: $0) }
        let source = try comparison(expected: amounts.reduce(.zero, +), actual: decimal(actual), breakdowns: breakdowns)
        let resolvedLocale = displayLocale ?? locale
        let model = PaycheckResultFormatting.renderModel(
            comparison: source, currencyCode: currencyCode, timeZoneIdentifier: "UTC", workTypes: [], locale: resolvedLocale
        )
        try expectNonZeroVisible(source.expected.expectedGross, text: model.expected, locale: resolvedLocale)
        try expectNonZeroVisible(source.actualGross.amount, text: model.actual, locale: resolvedLocale)
        try expectNonZeroVisible(source.difference, text: model.difference, locale: resolvedLocale)
        for (breakdown, row) in zip(breakdowns, model.breakdownRows) {
            try expectNonZeroVisible(breakdown.basePay, text: row.amount, locale: resolvedLocale)
            try expectNonZeroVisible(breakdown.appliedPayRate.amount, text: rateAmount(row.rate), locale: resolvedLocale)
        }
        return model
    }

    private func expectNonZeroVisible(_ source: Decimal, text: String, locale: Locale) throws {
        let displayed = try displayedAmount(text, locale: locale)
        #expect(source == .zero || displayed != .zero)
    }

    private func rateAmount(_ text: String) throws -> String {
        try #require(text.components(separatedBy: " / ").first)
    }

    private func expectReconciled(_ model: PaycheckResultView.RenderModel, locale: Locale) throws {
        let expected = try displayedAmount(model.expected, locale: locale)
        let actual = try displayedAmount(model.actual, locale: locale)
        let difference = try displayedAmount(model.difference, locale: locale)
        let rows = try model.breakdownRows.map { try displayedAmount($0.amount, locale: locale) }
        #expect(rows.reduce(.zero, +) == expected)
        #expect(actual - expected == difference)
    }

    private func displayedAmount(_ text: String, locale: Locale) throws -> Decimal {
        if text.hasSuffix(" EUR") {
            return try #require(Decimal(string: String(text.dropLast(4)), locale: self.locale))
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        let decimalSeparator = formatter.currencyDecimalSeparator ?? "."
        let withoutGroups = text.replacingOccurrences(of: formatter.currencyGroupingSeparator ?? ",", with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        let numeric = withoutGroups.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return try #require(Decimal(string: numeric, locale: self.locale))
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
