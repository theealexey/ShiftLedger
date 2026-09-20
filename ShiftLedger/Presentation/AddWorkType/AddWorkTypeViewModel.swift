import Foundation

enum AddWorkTypeSaveFailure: Error, Equatable {
    case invalidWorkType
    case persistence
}

enum AddWorkTypeSaveResult: Equatable {
    case saved(Job)
    case failed(AddWorkTypeSaveFailure)
    case invalid
    case ignored
}

enum AddWorkTypeValidationError: Error, Equatable {
    case incomplete
    case invalidPayRate
    case invalidPayRateHistory
}

@MainActor
final class AddWorkTypeViewModel {
    private(set) var nameText = ""
    private(set) var basePayBasis: BasePayBasis?
    private(set) var amountText = ""
    private(set) var isSaving = false

    let currencyCode: String

    private let decimalInputLocale: Locale
    private let saveWorkType: (WorkType) -> Result<Job, AddWorkTypeSaveFailure>
    private let makeWorkTypeID: () -> UUID
    private let makePayRateID: () -> UUID

    init(
        currencyCode: String,
        decimalInputLocale: Locale = .current,
        saveWorkType: @escaping (WorkType) -> Result<Job, AddWorkTypeSaveFailure>,
        makeWorkTypeID: @escaping () -> UUID = UUID.init,
        makePayRateID: @escaping () -> UUID = UUID.init
    ) {
        self.currencyCode = currencyCode
        self.decimalInputLocale = decimalInputLocale
        self.saveWorkType = saveWorkType
        self.makeWorkTypeID = makeWorkTypeID
        self.makePayRateID = makePayRateID
    }

    var normalizedName: String? {
        WorkTypeInputParser.normalizedName(nameText)
    }

    var amount: Decimal? {
        WorkTypeInputParser.decimalAmount(amountText, locale: decimalInputLocale)
    }

    var canSave: Bool {
        normalizedName != nil
            && basePayBasis != nil
            && (amount.map { $0 > .zero } ?? false)
            && isSaving == false
    }

    func updateNameText(_ value: String) {
        nameText = value
    }

    func selectBasePayBasis(_ basis: BasePayBasis) {
        guard basePayBasis != basis else {
            return
        }

        basePayBasis = basis
        amountText = ""
    }

    func updateAmountText(_ value: String) {
        amountText = value
    }

    func makeWorkType() throws(AddWorkTypeValidationError) -> WorkType {
        guard
            let normalizedName,
            let basePayBasis,
            let amount,
            amount > .zero
        else {
            throw .incomplete
        }

        let payRate: PayRate
        do {
            payRate = try PayRate(
                id: makePayRateID(),
                amount: amount,
                effectiveFrom: nil
            )
        } catch {
            throw .invalidPayRate
        }

        let payRateHistory: PayRateHistory
        do {
            payRateHistory = try PayRateHistory(payRates: [payRate])
        } catch {
            throw .invalidPayRateHistory
        }

        return WorkType(
            id: makeWorkTypeID(),
            name: normalizedName,
            basePayBasis: basePayBasis,
            payRateHistory: payRateHistory
        )
    }

    func save() -> AddWorkTypeSaveResult {
        guard isSaving == false else {
            return .ignored
        }
        guard canSave else {
            return .invalid
        }

        isSaving = true
        let workType: WorkType
        do {
            workType = try makeWorkType()
        } catch {
            isSaving = false
            return .invalid
        }

        switch saveWorkType(workType) {
        case let .success(job):
            return .saved(job)
        case let .failure(failure):
            isSaving = false
            return .failed(failure)
        }
    }
}
