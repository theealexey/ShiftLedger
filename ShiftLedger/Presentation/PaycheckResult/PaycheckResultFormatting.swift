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
        let formatter = currencyFormatter(currencyCode: currencyCode, locale: locale)
        guard amount != .zero else {
            return formattedCurrency(.zero, using: formatter)
                ?? exactFallback(.zero, currencyCode: currencyCode, includePositiveSign: false)
        }

        let magnitude = amount < .zero ? -amount : amount
        if formatsAsNonZero(magnitude, using: formatter) {
            return signedCurrency(amount, using: formatter)
                ?? exactFallback(amount, currencyCode: currencyCode, includePositiveSign: true)
        }

        let firstAdditionalDigit = formatter.maximumFractionDigits + 1
        if firstAdditionalDigit <= 38 {
            for fractionDigits in firstAdditionalDigit...38 {
                formatter.maximumFractionDigits = fractionDigits
                if formatsAsNonZero(magnitude, using: formatter) {
                    return signedCurrency(amount, using: formatter)
                        ?? exactFallback(amount, currencyCode: currencyCode, includePositiveSign: true)
                }
            }
        }

        return exactFallback(amount, currencyCode: currencyCode, includePositiveSign: true)
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
        dateFormatter.dateStyle = .medium
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
        let context = monetaryContext(comparison: comparison, currencyCode: currencyCode, locale: locale)
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
                rate: rate(
                    context.string(breakdown.appliedPayRate.amount),
                    basis: breakdown.basePayBasis
                ),
                amount: context.string(breakdown.basePay)
            )
        }

        return PaycheckResultView.RenderModel(
            expected: context.string(comparison.expected.expectedGross),
            actual: context.string(comparison.actualGross.amount),
            difference: context.string(comparison.difference, signed: true),
            explanation: explanation(for: comparison.difference),
            breakdownRows: rows,
            emptyBreakdownMessage: rows.isEmpty ? PaycheckResultStrings.breakdownEmpty : nil
        )
    }

    private struct MonetaryValues {
        let expected: Decimal
        let actual: Decimal
        let difference: Decimal
        let breakdownAmounts: [Decimal]
        let rates: [Decimal]

        var all: [Decimal] { [expected, actual, difference] + breakdownAmounts + rates }

        func rounded(to digits: Int) -> MonetaryValues {
            MonetaryValues(
                expected: roundedDecimal(expected, digits: digits),
                actual: roundedDecimal(actual, digits: digits),
                difference: roundedDecimal(difference, digits: digits),
                breakdownAmounts: breakdownAmounts.map { roundedDecimal($0, digits: digits) },
                rates: rates.map { roundedDecimal($0, digits: digits) }
            )
        }

        var reconciles: Bool {
            var sum = Decimal.zero
            for value in breakdownAmounts {
                var lhs = sum
                var rhs = value
                guard NSDecimalAdd(&sum, &lhs, &rhs, .bankers) == .noError else { return false }
            }
            var roundedActual = actual
            var roundedExpected = expected
            var subtraction = Decimal.zero
            return sum == expected
                && NSDecimalSubtract(&subtraction, &roundedActual, &roundedExpected, .bankers) == .noError
                && subtraction == difference
        }
    }

    // A nil precision/formatter selects exact text for every amount and rate.
    private struct MonetaryContext {
        let currencyCode: String
        let fractionDigits: Int?
        let formatter: NumberFormatter?

        func string(_ source: Decimal, signed: Bool = false) -> String {
            guard let fractionDigits, let formatter else {
                return exactFallback(source, currencyCode: currencyCode, includePositiveSign: signed)
            }
            let amount = roundedDecimal(source, digits: fractionDigits)
            let text = signed ? signedCurrency(amount, using: formatter) : formattedCurrency(amount, using: formatter)
            return text ?? exactFallback(source, currencyCode: currencyCode, includePositiveSign: signed)
        }
    }

    private static func roundedDecimal(_ value: Decimal, digits: Int) -> Decimal {
        var source = value
        var result = Decimal.zero
        NSDecimalRound(&result, &source, digits, .bankers)
        return result
    }

    // One display context for the entire Result; the Domain values remain exact.
    private static func monetaryContext(
        comparison: PaycheckComparison,
        currencyCode: String,
        locale: Locale
    ) -> MonetaryContext {
        let values = MonetaryValues(
            expected: comparison.expected.expectedGross,
            actual: comparison.actualGross.amount,
            difference: comparison.difference,
            breakdownAmounts: comparison.expected.shiftBreakdowns.map(\.basePay),
            rates: comparison.expected.shiftBreakdowns.map { $0.appliedPayRate.amount }
        )
        let formatter = currencyFormatter(currencyCode: currencyCode, locale: locale)
        formatter.roundingMode = .halfEven
        let normalDigits = formatter.maximumFractionDigits
        let exactDigits = values.all.reduce(normalDigits) { max($0, -$1.exponent) }

        if normalDigits >= 0 {
            for digits in normalDigits...exactDigits {
                let rounded = values.rounded(to: digits)
                guard rounded.all.allSatisfy({ !$0.isNaN }), rounded.reconciles,
                      zip(values.all, rounded.all).allSatisfy({ source, display in
                          source == .zero || display != .zero
                      })
                else { continue }

                formatter.maximumFractionDigits = digits
                if digits > normalDigits { formatter.minimumFractionDigits = digits }
                // NumberFormatter must not lose significant digits even for extreme Decimals.
                guard rounded.all.allSatisfy({ value in
                    guard let string = formattedCurrency(value, using: formatter) else { return false }
                    return displayedDecimal(string, using: formatter, negative: value < .zero) == value
                }) else { continue }
                return MonetaryContext(currencyCode: currencyCode, fractionDigits: digits, formatter: formatter)
            }
        }

        return MonetaryContext(currencyCode: currencyCode, fractionDigits: nil, formatter: nil)
    }

    private static func displayedDecimal(
        _ string: String,
        using formatter: NumberFormatter,
        negative: Bool
    ) -> Decimal? {
        let prefix = negative ? formatter.negativePrefix : formatter.positivePrefix
        let suffix = negative ? formatter.negativeSuffix : formatter.positiveSuffix
        var number = string
        if let prefix, number.hasPrefix(prefix) { number.removeFirst(prefix.count) }
        if let suffix, number.hasSuffix(suffix) { number.removeLast(suffix.count) }
        number = number.replacingOccurrences(of: formatter.currencyGroupingSeparator ?? ",", with: "")
            .replacingOccurrences(of: formatter.currencyDecimalSeparator ?? ".", with: ".")
        let normalized = number.map { character -> String in
            character.wholeNumberValue.map(String.init) ?? String(character)
        }.joined()
        guard let magnitude = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return negative ? -magnitude : magnitude
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

    private static func formatsAsNonZero(_ magnitude: Decimal, using formatter: NumberFormatter) -> Bool {
        guard
            let formattedMagnitude = formattedCurrency(magnitude, using: formatter),
            let formattedZero = formattedCurrency(.zero, using: formatter)
        else {
            return false
        }

        return formattedMagnitude != formattedZero
    }

    private static func signedCurrency(_ amount: Decimal, using formatter: NumberFormatter) -> String? {
        let originalPrefix = formatter.positivePrefix
        defer { formatter.positivePrefix = originalPrefix }
        if amount > .zero {
            formatter.positivePrefix = "+" + (formatter.positivePrefix ?? "")
        }
        return formattedCurrency(amount, using: formatter)
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
