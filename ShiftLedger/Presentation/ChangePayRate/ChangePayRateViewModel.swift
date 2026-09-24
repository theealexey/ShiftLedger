import Foundation

enum ChangePayRateSaveFailure: Error, Equatable {
    case persistence
}

enum ChangePayRateSaveResult: Equatable {
    case saved(Job)
    case failed(ChangePayRateSaveFailure)
    case invalid
    case ignored
}

@MainActor
final class ChangePayRateViewModel {
    let workType: WorkType
    let currencyCode: String
    let timeZoneIdentifier: String
    let jobTimeZone: TimeZone?
    private(set) var amountText = ""
    private(set) var effectiveDate: Date
    private(set) var isSaving = false

    private let decimalInputLocale: Locale
    private let savePayRate: (UUID, PayRate) -> Result<Job, ChangePayRateSaveFailure>
    private let makePayRateID: () -> UUID

    init(
        workType: WorkType,
        currencyCode: String,
        timeZoneIdentifier: String,
        decimalInputLocale: Locale = .current,
        initialEffectiveDate: Date = Date(),
        makePayRateID: @escaping () -> UUID = UUID.init,
        savePayRate: @escaping (UUID, PayRate) -> Result<Job, ChangePayRateSaveFailure>
    ) {
        self.workType = workType
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        jobTimeZone = TimeZone(identifier: timeZoneIdentifier)
        self.decimalInputLocale = decimalInputLocale
        effectiveDate = initialEffectiveDate
        self.makePayRateID = makePayRateID
        self.savePayRate = savePayRate
    }

    var amount: Decimal? {
        WorkTypeInputParser.decimalAmount(amountText, locale: decimalInputLocale)
    }

    var effectiveLocalDate: LocalDate? {
        guard let jobTimeZone else { return nil }
        return try? LocalDate(date: effectiveDate, in: jobTimeZone)
    }

    var hasDuplicateEffectiveDate: Bool {
        guard let effectiveLocalDate else { return false }
        return workType.payRates.contains { $0.effectiveFrom == effectiveLocalDate }
    }

    var canSave: Bool {
        amount.map { $0 > .zero } == true
            && effectiveLocalDate != nil
            && hasDuplicateEffectiveDate == false
            && isSaving == false
    }

    func updateAmountText(_ value: String) {
        amountText = value
    }

    func updateEffectiveDate(_ value: Date) {
        effectiveDate = value
    }

    func save() -> ChangePayRateSaveResult {
        guard isSaving == false else { return .ignored }
        guard canSave, let amount, let effectiveLocalDate else { return .invalid }

        let payRate: PayRate
        do {
            payRate = try PayRate(
                id: makePayRateID(),
                amount: amount,
                effectiveFrom: effectiveLocalDate
            )
        } catch {
            return .invalid
        }

        isSaving = true
        switch savePayRate(workType.id, payRate) {
        case let .success(job):
            return .saved(job)
        case let .failure(failure):
            isSaving = false
            return .failed(failure)
        }
    }
}
