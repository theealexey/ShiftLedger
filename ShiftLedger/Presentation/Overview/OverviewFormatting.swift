import Foundation

enum OverviewFormatting {
    struct PeriodHeading {
        let date: String
        let time: String?
        let accessibilityLabel: String
    }

    static func perShiftHeading(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> PeriodHeading? {
        guard let zone = TimeZone(identifier: timeZoneIdentifier),
              let time = compactShiftTimeRange(shift, timeZoneIdentifier: timeZoneIdentifier, locale: locale)
        else { return nil }
        let calendar = configuredCalendar(timeZone: zone)
        let date = dateHeading(shift, calendar: calendar, locale: locale, includeYear: true)
        let endpoint = DateFormatter()
        endpoint.calendar = calendar
        endpoint.timeZone = zone
        endpoint.locale = locale
        endpoint.dateStyle = .long
        endpoint.timeStyle = .short
        if zone.secondsFromGMT(for: shift.start) != zone.secondsFromGMT(for: shift.end) {
            endpoint.setLocalizedDateFormatFromTemplate("yMMMMdjmOOOO")
        }
        return PeriodHeading(date: date, time: time,
                             accessibilityLabel: "\(endpoint.string(from: shift.start)) — \(endpoint.string(from: shift.end))")
    }

    struct ShiftEndpoints: Equatable {
        let startTime: String
        let endTime: String
        let startDate: String?
        let endDate: String?
    }

    static func heroAmount(_ amount: Decimal, currencyCode: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.positivePrefix = ""
        formatter.positiveSuffix = ""
        formatter.negativePrefix = formatter.minusSign
        formatter.negativeSuffix = ""
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }

    static func compactScheduledPeriod(
        _ period: PayPeriod,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier),
              let end = try? period.endExclusive.addingDays(-1),
              let startDate = try? period.start.startOfDay(in: timeZone),
              let endDate = try? end.startOfDay(in: timeZone) else { return nil }
        let calendar = configuredCalendar(timeZone: timeZone)
        if calendar.component(.day, from: startDate) == 1,
           calendar.date(byAdding: .month, value: 1, to: startDate)
            == (try? period.endExclusive.startOfDay(in: timeZone)) {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: startDate)
        }
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateTemplate = "yMMMd"
        return formatter.string(from: startDate, to: endDate)
    }

    static func compactPerShiftPeriod(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale,
        referenceDate: Date = Date()
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        let calendar = configuredCalendar(timeZone: timeZone)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        let needsYear = calendar.component(.year, from: shift.start)
            != calendar.component(.year, from: referenceDate)
        formatter.setLocalizedDateFormatFromTemplate(needsYear ? "yMMMdjm" : "MMMdjm")
        return formatter.string(from: shift.start)
    }

    static func currency(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> String {
        guard let digits = currencyFractionDigits(currencyCode: currencyCode, locale: locale) else {
            return amount.description
        }
        return amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(digits))
                .rounded(rule: .toNearestOrEven)
                .locale(locale)
        )
    }

    static func exactCurrency(
        _ amount: Decimal,
        currencyCode: String,
        locale: Locale
    ) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let standardDigits = formatter.maximumFractionDigits
        formatter.minimumFractionDigits = standardDigits
        formatter.maximumFractionDigits = 38
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    /// The numeric value represented by `currency`, without parsing localized text.
    /// Both paths use the currency's fraction digits and ties-to-even rounding.
    static func displayedCurrencyValue(_ amount: Decimal, currencyCode: String, locale: Locale) -> Decimal? {
        guard !amount.isNaN,
              let digits = currencyFractionDigits(currencyCode: currencyCode, locale: locale) else {
            return nil
        }
        var source = amount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, digits, .bankers)
        return rounded.isNaN ? nil : rounded
    }

    private static func currencyFractionDigits(currencyCode: String, locale: Locale) -> Int? {
        guard Locale.Currency(currencyCode).isISOCurrency else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let digits = formatter.maximumFractionDigits
        guard (0...38).contains(digits), formatter.minimumFractionDigits == digits,
              formatter.roundingMode == .halfEven,
              formatter.roundingIncrement?.decimalValue == .zero else { return nil }
        return digits
    }

    static func scheduledPeriod(
        _ period: PayPeriod,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let visibleEnd = try? period.endExclusive.addingDays(-1),
            let startDate = try? period.start.startOfDay(in: timeZone),
            let endDate = try? visibleEnd.startOfDay(in: timeZone)
        else {
            return nil
        }

        let calendar = configuredCalendar(timeZone: timeZone)
        if calendar.component(.day, from: startDate) == 1,
           calendar.date(byAdding: .month, value: 1, to: startDate)
            == (try? period.endExclusive.startOfDay(in: timeZone)) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: startDate)
        }
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateTemplate = "yMMMMd"
        return formatter.string(from: startDate, to: endDate)
    }

    static func perShiftPeriod(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateIntervalFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: shift.start, to: shift.end)
    }

    static func shiftDate(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: shift.start)
    }

    static func frontShiftDate(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale,
        referenceDate: Date = Date()
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let calendar = configuredCalendar(timeZone: timeZone)
        let referenceYear = calendar.component(.year, from: referenceDate)
        let needsYear = calendar.component(.year, from: shift.start) != referenceYear
            || calendar.component(.year, from: shift.end) != referenceYear
        return dateHeading(shift, calendar: calendar, locale: locale, includeYear: needsYear)
    }

    private static func dateHeading(
        _ shift: Shift, calendar: Calendar, locale: Locale, includeYear: Bool
    ) -> String {
        let timeZone = calendar.timeZone
        let template = includeYear ? "yMMMMd" : "MMMMd"
        if !calendar.isDate(shift.start, inSameDayAs: shift.end) {
            let interval = DateIntervalFormatter()
            interval.calendar = calendar
            interval.locale = locale
            interval.timeZone = timeZone
            interval.dateTemplate = template
            return interval.string(from: shift.start, to: shift.end)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: shift.start)
    }

    static func shiftEndpoints(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> ShiftEndpoints? {
        guard
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            shift.end > shift.start
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let startTime = formatter.string(from: shift.start)
        let endTime = formatter.string(from: shift.end)
        let calendar = configuredCalendar(timeZone: timeZone)
        let sameDay = calendar.isDate(shift.start, inSameDayAs: shift.end)
        let sameYear = calendar.component(.year, from: shift.start)
            == calendar.component(.year, from: shift.end)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "dMMM" : "dMMMy")

        return ShiftEndpoints(
            startTime: startTime,
            endTime: endTime,
            startDate: sameDay ? nil : formatter.string(from: shift.start),
            endDate: sameDay ? nil : formatter.string(from: shift.end)
        )
    }

    static func shiftTimeRange(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateIntervalFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: shift.start, to: shift.end)
    }

    static func compactShiftTimeRange(
        _ shift: Shift,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let calendar = configuredCalendar(timeZone: timeZone)
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let startTime = timeFormatter.string(from: shift.start)
        let endTime = timeFormatter.string(from: shift.end)
        if startTime == endTime,
           timeZone.secondsFromGMT(for: shift.start) != timeZone.secondsFromGMT(for: shift.end) {
            timeFormatter.setLocalizedDateFormatFromTemplate("jmOOOO")
            return "\(timeFormatter.string(from: shift.start))–\(timeFormatter.string(from: shift.end))"
        }
        return "\(startTime)–\(endTime)"
    }

    static func unpaidBreakTimeRange(
        _ unpaidBreak: UnpaidBreak,
        timeZoneIdentifier: String,
        locale: Locale,
        includeDate: Bool = false
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let calendar = configuredCalendar(timeZone: timeZone)
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = includeDate || !calendar.isDate(unpaidBreak.start, inSameDayAs: unpaidBreak.end)
            ? .medium : .none
        formatter.timeStyle = .short
        return formatter.string(from: unpaidBreak.start, to: unpaidBreak.end)
    }

    static func rate(
        amount: Decimal,
        basis: BasePayBasis,
        currencyCode: String,
        locale: Locale
    ) -> String? {
        guard let formatted = exactCurrency(amount, currencyCode: currencyCode, locale: locale) else { return nil }
        let unit = basis == .hourly ? PaycheckResultStrings.rateHour : PaycheckResultStrings.rateShift
        return "\(formatted) / \(unit)"
    }

    static func duration(_ duration: TimeInterval) -> String {
        PaycheckResultFormatting.paidDuration(duration)
    }

    private static func configuredCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
