import Foundation

struct OverviewShiftCardMapper {
    private enum MappingError: Error {
        case invalidFormatting
    }

    private let currencyCode: String
    private let timeZoneIdentifier: String
    private let displayLocale: Locale

    init(
        currencyCode: String,
        timeZoneIdentifier: String,
        displayLocale: Locale
    ) {
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayLocale = displayLocale
    }

    func map(
        _ shiftBreakdowns: [ShiftPayBreakdown],
        selectedShiftID: UUID?,
        expandedShiftID: UUID?
    ) throws -> [OverviewView.ShiftCard] {
        try shiftBreakdowns.reversed().map { shiftBreakdown in
            let shift = shiftBreakdown.shift
            guard
                let frontDate = OverviewFormatting.frontShiftDate(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let endpoints = OverviewFormatting.shiftEndpoints(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let compactTimeRange = OverviewFormatting.compactShiftTimeRange(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let accessibilityDate = OverviewFormatting.shiftDate(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                ),
                let accessibilityTimeRange = OverviewFormatting.shiftTimeRange(
                    shift,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                )
            else {
                throw MappingError.invalidFormatting
            }

            let expectedAmount = OverviewFormatting.currency(
                shiftBreakdown.basePay,
                currencyCode: currencyCode,
                locale: displayLocale
            )
            guard let exactAmount = OverviewFormatting.exactCurrency(
                shiftBreakdown.basePay,
                currencyCode: currencyCode,
                locale: displayLocale
            ) else {
                throw MappingError.invalidFormatting
            }
            let exactExpectedAmount = exactAmount == expectedAmount ? nil : exactAmount
            guard let appliedRateAmount = OverviewFormatting.exactCurrency(
                shiftBreakdown.appliedPayRate.amount,
                currencyCode: currencyCode,
                locale: displayLocale
            ), let appliedRate = OverviewFormatting.rate(
                amount: shiftBreakdown.appliedPayRate.amount,
                basis: shiftBreakdown.basePayBasis,
                currencyCode: currencyCode,
                locale: displayLocale
            ) else { throw MappingError.invalidFormatting }
            let paidDuration = OverviewFormatting.duration(shiftBreakdown.paidDuration)
            let unpaidBreak = shift.unpaidBreak.map {
                OverviewFormatting.duration($0.end.timeIntervalSince($0.start))
            }
            let unpaidBreakTimeRange = shift.unpaidBreak.flatMap {
                OverviewFormatting.unpaidBreakTimeRange(
                    $0,
                    timeZoneIdentifier: timeZoneIdentifier,
                    locale: displayLocale
                )
            }
            let payBasis: String
            switch shiftBreakdown.basePayBasis {
            case .hourly:
                payBasis = JobSetupStrings.hourlyBasis
            case .fixedPerShift:
                payBasis = JobSetupStrings.fixedPerShiftBasis
            }
            let accessibilityLabel = [
                accessibilityDate,
                "\(PaycheckResultStrings.shiftExpected): \(expectedAmount)",
                accessibilityTimeRange,
                "\(PaycheckResultStrings.paidTime): \(paidDuration)",
                unpaidBreak.map { "\(AddShiftStrings.unpaidBreak): \($0)" }
            ]
            .compactMap { $0 }
            .joined(separator: ", ")

            return OverviewView.ShiftCard(
                id: shift.id,
                frontDate: frontDate,
                timeRange: compactTimeRange,
                endpoints: endpoints,
                expectedAmount: expectedAmount,
                exactExpectedAmount: exactExpectedAmount,
                paidDuration: paidDuration,
                unpaidBreak: unpaidBreak,
                unpaidBreakTimeRange: unpaidBreakTimeRange,
                appliedRate: appliedRate,
                appliedRateAmount: appliedRateAmount,
                payBasis: payBasis,
                isSelected: shift.id == selectedShiftID,
                isExpanded: shift.id == expandedShiftID,
                accessibilityLabel: accessibilityLabel
            )
        }
    }
}
