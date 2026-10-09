import Foundation

enum ArchivedJobHistoryError: Error {
    case jobNotFound(jobID: UUID)
    case jobNotArchived(jobID: UUID)
    case invalidShiftBreakdown(shiftID: UUID)
    case totalArithmeticFailed
}

@MainActor
enum ArchivedJobHistoryAssembly {
    static func load(id: UUID, stack: CoreDataStack, locale: Locale = .autoupdatingCurrent) throws -> ArchivedJobHistoryContent {
        let catalog = try JobStorage(stack: stack).loadCatalog()
        guard let entry = catalog.first(where: { $0.job.id == id }) else {
            throw ArchivedJobHistoryError.jobNotFound(jobID: id)
        }
        guard entry.isArchived else { throw ArchivedJobHistoryError.jobNotArchived(jobID: id) }
        let job = entry.job
        let shifts = try ShiftStorage(stack: stack).loadAll(forJobID: id).sorted {
            if $0.start != $1.start { return $0.start > $1.start }
            if $0.end != $1.end { return $0.end > $1.end }
            return $0.id.uuidString < $1.id.uuidString
        }
        var total = Decimal.zero
        let rows = try shifts.map { shift in
            let period = try job.payCalculationPeriod(for: shift)
            let expected = try job.expectedGrossBreakdown(for: period, from: [shift])
            guard expected.shiftBreakdowns.count == 1, let breakdown = expected.shiftBreakdowns.first,
                  breakdown.shift.id == shift.id, breakdown.basePay == expected.expectedGross else {
                throw ArchivedJobHistoryError.invalidShiftBreakdown(shiftID: shift.id)
            }
            var lhs = total
            var rhs = breakdown.basePay
            guard NSDecimalAdd(&total, &lhs, &rhs, .bankers) == .noError else {
                throw ArchivedJobHistoryError.totalArithmeticFailed
            }
            let unit = breakdown.basePayBasis == .hourly ? PaycheckResultStrings.rateHour : PaycheckResultStrings.rateShift
            let workTypeName = job.workTypes.first(where: { $0.id == shift.workTypeID })?.name ?? PaycheckResultStrings.unnamedWorkType
            return ArchivedJobHistoryContent.Row(
                id: shift.id,
                title: PaycheckResultFormatting.shiftDateTime(shift, timeZoneIdentifier: job.timeZoneIdentifier, locale: locale),
                detail: "\(workTypeName)\n\(PaycheckResultStrings.paidTime): \(PaycheckResultFormatting.paidDuration(breakdown.paidDuration))\n\(PaycheckResultStrings.rate): \(money(breakdown.appliedPayRate.amount, currency: job.currencyCode, locale: locale)) / \(unit)\n\(PaycheckResultStrings.shiftExpected): \(money(breakdown.basePay, currency: job.currencyCode, locale: locale))",
                contribution: breakdown.basePay
            )
        }
        return ArchivedJobHistoryContent(
            identity: JobSelectionItem(id: job.id, name: entry.name, currencyCode: job.currencyCode, timeZoneIdentifier: job.timeZoneIdentifier, isArchived: true),
            total: total, totalText: money(total, currency: job.currencyCode, locale: locale), rows: rows
        )
    }

    private static func money(_ amount: Decimal, currency: String, locale: Locale) -> String {
        var value = amount
        return "\(NSDecimalString(&value, locale as NSLocale)) \(currency)"
    }
}
