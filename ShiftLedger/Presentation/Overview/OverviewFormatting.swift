import Foundation

enum OverviewFormatting {
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
        locale: Locale,
        referenceDate: Date = Date()
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
        let referenceYear = calendar.component(.year, from: referenceDate)
        let needsYear = calendar.component(.year, from: startDate) != referenceYear
            || calendar.component(.year, from: endDate) != referenceYear
        formatter.dateTemplate = needsYear ? "yMMMd" : "MMMd"
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
        amount.formatted(.currency(code: currencyCode).locale(locale))
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

        let formatter = DateIntervalFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
        locale: Locale
    ) -> String? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = configuredCalendar(timeZone: timeZone)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
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
        guard calendar.isDate(shift.start, inSameDayAs: shift.end) == false else {
            return "\(startTime)–\(endTime)"
        }

        let endDateFormatter = DateFormatter()
        endDateFormatter.calendar = calendar
        endDateFormatter.locale = locale
        endDateFormatter.timeZone = timeZone
        let sharesMonth = calendar.component(.month, from: shift.start)
            == calendar.component(.month, from: shift.end)
            && calendar.component(.year, from: shift.start) == calendar.component(.year, from: shift.end)
        endDateFormatter.setLocalizedDateFormatFromTemplate(sharesMonth ? "d" : "MMMd")
        return "\(startTime) → \(endDateFormatter.string(from: shift.end)), \(endTime)"
    }

    static func unpaidBreakTimeRange(
        _ unpaidBreak: UnpaidBreak,
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
        return formatter.string(from: unpaidBreak.start, to: unpaidBreak.end)
    }

    static func rate(
        amount: Decimal,
        basis: BasePayBasis,
        currencyCode: String,
        locale: Locale
    ) -> String {
        PaycheckResultFormatting.rate(
            amount: amount,
            basis: basis,
            currencyCode: currencyCode,
            locale: locale
        )
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
