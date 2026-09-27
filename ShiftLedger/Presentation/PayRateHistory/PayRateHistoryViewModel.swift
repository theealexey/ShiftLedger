import Foundation

struct PayRateHistoryViewModel {
    enum RowKind: Equatable {
        case effectiveFrom(LocalDate)
        case initial
    }

    struct Row: Equatable {
        let id: UUID
        let amountAndBasis: String
        let effectiveDateDescription: String
        let accessibilityLabel: String
        let kind: RowKind
    }

    let workTypeName: String
    let rows: [Row]

    init(
        workType: WorkType,
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale = CurrencySelectionItem.applicationDisplayLocale
    ) {
        workTypeName = workType.name ?? WorkTypesStrings.unnamed
        rows = Self.ordered(workType.payRates).map { payRate in
            Self.makeRow(
                payRate: payRate,
                basis: workType.basePayBasis,
                currencyCode: currencyCode,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: displayLocale
            )
        }
    }

    private static func ordered(_ payRates: [PayRate]) -> [PayRate] {
        payRates.sorted { lhs, rhs in
            switch (lhs.effectiveFrom, rhs.effectiveFrom) {
            case let (lhsDate?, rhsDate?):
                lhsDate > rhsDate
            case (.some, .none):
                true
            case (.none, .some):
                false
            case (.none, .none):
                false
            }
        }
    }

    private static func makeRow(
        payRate: PayRate,
        basis: BasePayBasis,
        currencyCode: String,
        timeZoneIdentifier: String,
        locale: Locale
    ) -> Row {
        let amount = PaycheckResultFormatting.currency(
            payRate.amount,
            currencyCode: currencyCode,
            locale: locale
        )
        let amountAndBasis = PaycheckResultFormatting.rate(
            amount: payRate.amount,
            basis: basis,
            currencyCode: currencyCode,
            locale: locale
        )
        let accessibleRate = switch basis {
        case .hourly:
            PayRateHistoryStrings.accessibilityHourlyRate(amount, locale: locale)
        case .fixedPerShift:
            PayRateHistoryStrings.accessibilityPerShiftRate(amount, locale: locale)
        }

        guard let effectiveFrom = payRate.effectiveFrom else {
            return Row(
                id: payRate.id,
                amountAndBasis: amountAndBasis,
                effectiveDateDescription: PayRateHistoryStrings.initialRate,
                accessibilityLabel: PayRateHistoryStrings.accessibilityInitialRate(
                    accessibleRate,
                    locale: locale
                ),
                kind: .initial
            )
        }

        let mediumDate = formatted(
            effectiveFrom,
            timeZoneIdentifier: timeZoneIdentifier,
            locale: locale,
            dateStyle: .medium
        )
        let longDate = formatted(
            effectiveFrom,
            timeZoneIdentifier: timeZoneIdentifier,
            locale: locale,
            dateStyle: .long
        )
        return Row(
            id: payRate.id,
            amountAndBasis: amountAndBasis,
            effectiveDateDescription: PayRateHistoryStrings.effectiveFrom(
                mediumDate,
                locale: locale
            ),
            accessibilityLabel: PayRateHistoryStrings.accessibilityEffectiveFrom(
                rate: accessibleRate,
                date: longDate,
                locale: locale
            ),
            kind: .effectiveFrom(effectiveFrom)
        )
    }

    private static func formatted(
        _ localDate: LocalDate,
        timeZoneIdentifier: String,
        locale: Locale,
        dateStyle: DateFormatter.Style
    ) -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier),
              let date = try? localDate.startOfDay(in: timeZone)
        else {
            return String(format: "%04d-%02d-%02d", localDate.year, localDate.month, localDate.day)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
