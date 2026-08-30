enum PayCalculationCycleKind: Equatable {
    case perShift
    case weekly
    case biweekly
    case calendarMonthly
}

struct JobSetupDraft: Equatable {
    var name: String
    var hourlyRateText: String
    var currencyCode: String
    var timeZoneIdentifier: String
    var payCalculationCycleKind: PayCalculationCycleKind?
    var payPeriodAnchorDate: LocalDate?
}
