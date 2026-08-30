enum PayPeriodFrequency: Equatable {
    case weekly
    case biweekly
    case calendarMonthly
}

struct JobSetupDraft: Equatable {
    var name: String
    var hourlyRateText: String
    var currencyCode: String
    var timeZoneIdentifier: String
    var payPeriodFrequency: PayPeriodFrequency?
    var payPeriodAnchorDate: LocalDate?
}
