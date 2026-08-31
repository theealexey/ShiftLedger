enum PayCalculationCycleKind: Equatable {
    case perShift
    case weekly
    case biweekly
    case calendarMonthly
}

struct JobSetupDraft: Equatable {
    var basePayAmountText: String
    var currencyCode: String
    var timeZoneIdentifier: String
    var basePayBasis: BasePayBasis?
    var payCalculationCycleKind: PayCalculationCycleKind?
    var payPeriodAnchorDate: LocalDate?
}
