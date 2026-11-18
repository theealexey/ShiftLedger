import Foundation

enum PaycheckResultFormatting {
    static func currency(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> String {
        let formatter = currencyFormatter(currencyCode: currencyCode, locale: locale)
        return formattedCurrency(amount, using: formatter)
            ?? exactFallback(amount, currencyCode: currencyCode, includePositiveSign: false)
    }

    static func difference(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> String {
        MonetaryContext(currencyCode: currencyCode, locale: locale).amount(amount, signed: true).text
    }

    static func explanation(for difference: Decimal) -> String {
        if difference < .zero {
            return PaycheckResultStrings.lower
        }
        if difference > .zero {
            return PaycheckResultStrings.higher
        }
        return PaycheckResultStrings.equal
    }

    static func shiftDateTime(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = .gmt
            return "\(formatter.string(from: shift.start)) – \(formatter.string(from: shift.end))"
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        if calendar.isDate(shift.start, inSameDayAs: shift.end) {
            return "\(dateFormatter.string(from: shift.start)) · "
                + "\(timeFormatter.string(from: shift.start))–\(timeFormatter.string(from: shift.end))"
        }

        return "\(dateFormatter.string(from: shift.start)), \(timeFormatter.string(from: shift.start)) "
            + "– \(dateFormatter.string(from: shift.end)), \(timeFormatter.string(from: shift.end))"
    }

    static func paidDuration(_ paidDuration: TimeInterval) -> String {
        if paidDuration > 0, paidDuration < 0.5 {
            return PaycheckResultStrings.durationLessThanSecond
        }

        let wholeSeconds = max(0, Int(paidDuration.rounded()))
        let hours = wholeSeconds / 3_600
        let minutes = wholeSeconds % 3_600 / 60
        let seconds = wholeSeconds % 60
        var components: [String] = []

        if hours > 0 {
            components.append("\(hours) \(PaycheckResultStrings.durationHour)")
        }
        if minutes > 0 {
            components.append("\(minutes) \(PaycheckResultStrings.durationMinute)")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds) \(PaycheckResultStrings.durationSecond)")
        }

        return components.joined(separator: " ")
    }

    static func rate(
        amount: Decimal,
        basis: BasePayBasis,
        currencyCode: String,
        locale: Locale
    ) -> String {
        rate(currency(amount, currencyCode: currencyCode, locale: locale), basis: basis)
    }

    private static func rate(_ formattedAmount: String, basis: BasePayBasis) -> String {
        let unit = switch basis {
        case .hourly:
            PaycheckResultStrings.rateHour
        case .fixedPerShift:
            PaycheckResultStrings.rateShift
        }

        return "\(formattedAmount) / \(unit)"
    }

    static func renderModel(
        comparison: PaycheckComparison,
        currencyCode: String,
        timeZoneIdentifier: String,
        workTypes: [WorkType],
        locale: Locale
    ) -> PaycheckResultView.RenderModel {
        let context = MonetaryContext(currencyCode: currencyCode, locale: locale)
        let expected = context.amount(comparison.expected.expectedGross)
        let actual = context.amount(comparison.actualGross.amount)
        let difference = context.amount(comparison.difference, signed: true)
        let rows = comparison.expected.shiftBreakdowns.map { breakdown in
            PaycheckResultView.BreakdownRow(
                workTypeName: workTypes.first(where: { $0.id == breakdown.shift.workTypeID })?.name
                    ?? PaycheckResultStrings.unnamedWorkType,
                date: shiftDateTime(
                    breakdown.shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: locale
                ),
                duration: paidDuration(breakdown.paidDuration),
                rate: context.amount(breakdown.appliedPayRate.amount).per(breakdown.basePayBasis),
                amount: context.amount(breakdown.basePay)
            )
        }
        let hasApproximation = [expected, actual, difference].contains(where: \.isApproximate)
            || rows.contains { $0.rate.isApproximate || $0.amount.isApproximate }

        return PaycheckResultView.RenderModel(
            expectedAmount: expected,
            actualAmount: actual,
            differenceAmount: difference,
            explanation: explanation(for: comparison.difference),
            approximationNote: hasApproximation ? PaycheckResultStrings.approximationNote : nil,
            breakdownRows: rows,
            emptyBreakdownMessage: rows.isEmpty ? PaycheckResultStrings.breakdownEmpty : nil
        )
    }

    struct Amount {
        let text: String
        let accessibilityText: String
        let exact: String
        let isApproximate: Bool
        let isBound: Bool

        var needsExactDetail: Bool { isApproximate || isBound }

        func per(_ basis: BasePayBasis) -> Self {
            Self(
                text: rate(text, basis: basis),
                accessibilityText: rate(accessibilityText, basis: basis),
                exact: rate(exact, basis: basis),
                isApproximate: isApproximate,
                isBound: isBound
            )
        }
    }

    private struct MonetaryContext {
        let currencyCode: String
        let locale: Locale
        let formatter: NumberFormatter
        let fractionDigits: Int
        let minorUnit: Decimal

        init(currencyCode: String, locale: Locale) {
            self.currencyCode = currencyCode
            self.locale = locale
            formatter = currencyFormatter(currencyCode: currencyCode, locale: locale)
            fractionDigits = formatter.maximumFractionDigits
            minorUnit = Decimal(sign: .plus, exponent: -fractionDigits, significand: 1)
        }

        func amount(_ source: Decimal, signed: Bool = false) -> Amount {
            let exact = exactText(source, signed: signed)
            let magnitude = abs(source)
            if magnitude != .zero, magnitude < minorUnit {
                let bound = compactCurrency(minorUnit)
                let sign = source < .zero ? "-" : signed ? "+" : ""
                return Amount(
                    text: "\(sign)<\(bound)",
                    accessibilityText: PaycheckResultStrings.belowMinorUnit(
                        bound, negative: source < .zero, isDifference: signed
                    ),
                    exact: exact,
                    isApproximate: false,
                    isBound: true
                )
            }

            // Scientific notation keeps exceptionally large integer amounts readable too.
            // The unabridged value is always available in the exact section.
            let display: String
            let isApproximate: Bool
            let sign = signed && source > .zero ? "+" : ""
            if magnitude >= 100_000_000 {
                let style = Decimal.FormatStyle(locale: locale)
                    .notation(.scientific)
                    .precision(.significantDigits(1...4))
                display = "\(sign)\(source.formatted(style)) \(currencyCode)"
                isApproximate = true
            } else {
                var value = source
                var rounded = Decimal.zero
                NSDecimalRound(&rounded, &value, fractionDigits, .bankers)
                display = sign + compactCurrency(rounded)
                isApproximate = rounded != source
            }
            return Amount(
                text: isApproximate ? "≈" + display : display,
                accessibilityText: isApproximate ? PaycheckResultStrings.approximate(display) : display,
                exact: exact,
                isApproximate: isApproximate,
                isBound: false
            )
        }

        private func compactCurrency(_ value: Decimal) -> String {
            value.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale)
                .precision(.fractionLength(fractionDigits)))
        }

        private func exactText(_ source: Decimal, signed: Bool) -> String {
            // NumberFormatter can drop significant digits on conversion to number formats.
            // Localize the decimal separator on the original full-precision representation.
            let number = NSDecimalNumber(decimal: source).stringValue.replacingOccurrences(
                of: ".", with: formatter.currencyDecimalSeparator ?? "."
            )
            let sign = signed && source > .zero ? "+" : ""
            return "\(sign)\(number) \(currencyCode)"
        }
    }

    private static func currencyFormatter(currencyCode: String, locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter
    }

    private static func formattedCurrency(_ amount: Decimal, using formatter: NumberFormatter) -> String? {
        formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    private static func exactFallback(
        _ amount: Decimal,
        currencyCode: String,
        includePositiveSign: Bool
    ) -> String {
        let value = NSDecimalNumber(decimal: amount).stringValue
        let sign = includePositiveSign && amount > .zero ? "+" : ""
        return "\(sign)\(value) \(currencyCode)"
    }
}
