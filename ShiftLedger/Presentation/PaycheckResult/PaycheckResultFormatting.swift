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
        let wholeSeconds = Int(paidDuration)
        let hours = wholeSeconds / 3_600
        let minutes = wholeSeconds % 3_600 / 60
        let elapsedBeforeSeconds = hours * 3_600 + minutes * 60
        let seconds = paidDuration - TimeInterval(elapsedBeforeSeconds)
        var components: [String] = []

        if hours > 0 {
            components.append("\(hours) \(PaycheckResultStrings.durationHour)")
        }
        if minutes > 0 {
            components.append("\(minutes) \(PaycheckResultStrings.durationMinute)")
        }
        if seconds > 0 || components.isEmpty {
            let wholeSecondComponent = Int(seconds)
            let secondsText = seconds == TimeInterval(wholeSecondComponent)
                ? String(wholeSecondComponent)
                : String(seconds)
            components.append("\(secondsText) \(PaycheckResultStrings.durationSecond)")
        }

        return components.joined(separator: " ")
    }

    static func rate(
        amount: Decimal,
        basis: BasePayBasis,
        currencyCode: String,
        locale: Locale
    ) -> String {
        let unit = switch basis {
        case .hourly:
            PaycheckResultStrings.rateHour
        case .fixedPerShift:
            PaycheckResultStrings.rateShift
        }

        return "\(currency(amount, currencyCode: currencyCode, locale: locale)) / \(unit)"
    }

    static func renderModel(
        comparison: PaycheckComparison,
        currencyCode: String,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> PaycheckResultView.RenderModel {
        let rows = comparison.expected.shiftBreakdowns.map { breakdown in
            PaycheckResultView.BreakdownRow(
                date: shiftDateTime(
                    breakdown.shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: locale
                ),
                duration: paidDuration(breakdown.paidDuration),
                rate: rate(
                    amount: breakdown.appliedPayRate.amount,
                    basis: breakdown.basePayBasis,
                    currencyCode: currencyCode,
                    locale: locale
                ),
                amount: currency(
                    breakdown.basePay,
                    currencyCode: currencyCode,
                    locale: locale
                )
            )
        }

        return PaycheckResultView.RenderModel(
            expected: currency(
                comparison.expected.expectedGross,
                currencyCode: currencyCode,
                locale: locale
            ),
            actual: currency(
                comparison.actualGross.amount,
                currencyCode: currencyCode,
                locale: locale
            ),
            difference: difference(
                comparison.difference,
                currencyCode: currencyCode,
                locale: locale
            ),
            explanation: explanation(for: comparison.difference),
            breakdownRows: rows,
            emptyBreakdownMessage: rows.isEmpty ? PaycheckResultStrings.breakdownEmpty : nil
        )
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
