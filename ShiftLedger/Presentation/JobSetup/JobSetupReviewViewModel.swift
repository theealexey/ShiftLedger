import Foundation

enum JobSetupReviewError: Error, Equatable {
    case incompleteDraft
    case invalidTimeZoneIdentifier
}

enum JobSetupReviewSaveFailure: Error, Equatable {
    case invalidDraft
    case persistence
}

enum JobSetupReviewSaveResult: Equatable {
    case saved(Job)
    case failed(JobSetupReviewSaveFailure)
    case invalid
    case ignored
}

@MainActor
final class JobSetupReviewViewModel {
    private(set) var draft: JobSetupDraft
    private(set) var isSaving = false
    private let decimalInputLocale: Locale
    private let saveJob: (Job) -> Result<Void, JobSetupReviewSaveFailure>

    init(
        draft: JobSetupDraft,
        decimalInputLocale: Locale = .current,
        saveJob: @escaping (Job) -> Result<Void, JobSetupReviewSaveFailure>
    ) {
        self.draft = draft
        self.decimalInputLocale = decimalInputLocale
        self.saveJob = saveJob
    }

    var basePayLabel: String? {
        switch draft.basePayBasis {
        case .hourly:
            JobSetupReviewStrings.hourlyPay
        case .fixedPerShift:
            JobSetupReviewStrings.fixedPerShiftPay
        case nil:
            nil
        }
    }

    var amount: Decimal? {
        JobSetupViewModel.parseDecimal(draft.basePayAmountText, locale: decimalInputLocale)
    }

    var amountText: String? {
        amount == nil ? nil : draft.basePayAmountText
    }

    var payPeriodLabel: String? {
        switch draft.payCalculationCycleKind {
        case .perShift:
            JobSetupReviewStrings.perShiftPeriod
        case .weekly:
            JobSetupReviewStrings.weeklyPeriod
        case .biweekly:
            JobSetupReviewStrings.biweeklyPeriod
        case .calendarMonthly:
            JobSetupReviewStrings.calendarMonthlyPeriod
        case nil:
            nil
        }
    }

    var showsPeriodStart: Bool {
        draft.payCalculationCycleKind == .weekly || draft.payCalculationCycleKind == .biweekly
    }

    var canFinish: Bool {
        guard
            draft.basePayBasis != nil,
            let amount,
            amount > .zero,
            payCalculationCycle != nil,
            TimeZone(identifier: draft.timeZoneIdentifier) != nil
        else {
            return false
        }

        return true
    }

    var payCalculationCycle: PayCalculationCycle? {
        switch (draft.payCalculationCycleKind, draft.payPeriodAnchorDate) {
        case (.perShift, _):
            .perShift
        case let (.weekly, anchorDate?):
            .scheduled(.weekly(anchorDate: anchorDate))
        case let (.biweekly, anchorDate?):
            .scheduled(.biweekly(anchorDate: anchorDate))
        case (.calendarMonthly, _):
            .scheduled(.calendarMonthly)
        case (.weekly, nil), (.biweekly, nil), (nil, _):
            nil
        }
    }

    func selectTimeZone(identifier: String) -> Bool {
        guard TimeZone.knownTimeZoneIdentifiers.contains(identifier) else {
            return false
        }

        draft.timeZoneIdentifier = identifier
        return true
    }

    func makeJob(createdAt: Date = Date()) throws -> Job {
        guard
            canFinish,
            let basePayBasis = draft.basePayBasis,
            let amount,
            let payCalculationCycle
        else {
            throw JobSetupReviewError.incompleteDraft
        }

        guard TimeZone(identifier: draft.timeZoneIdentifier) != nil else {
            throw JobSetupReviewError.invalidTimeZoneIdentifier
        }

        let initialPayRate = try PayRate(amount: amount, effectiveFrom: nil)
        return try Job(
            currencyCode: draft.currencyCode,
            timeZoneIdentifier: draft.timeZoneIdentifier,
            basePayBasis: basePayBasis,
            payCalculationCycle: payCalculationCycle,
            payRates: [initialPayRate],
            createdAt: createdAt
        )
    }

    func save(createdAt: Date = Date()) -> JobSetupReviewSaveResult {
        guard isSaving == false else {
            return .ignored
        }
        guard canFinish else {
            return .invalid
        }

        isSaving = true

        let job: Job
        do {
            job = try makeJob(createdAt: createdAt)
        } catch {
            isSaving = false
            return .failed(.invalidDraft)
        }

        switch saveJob(job) {
        case .success:
            return .saved(job)
        case let .failure(failure):
            isSaving = false
            return .failed(failure)
        }
    }
}
