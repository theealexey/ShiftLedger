import Foundation

@MainActor
enum JobSetupAssembly {
    static func makeStart(
        initialCurrencyCode: String,
        initialTimeZoneIdentifier: String
    ) -> JobSetupViewController {
        let viewModel = JobSetupViewModel(
            initialCurrencyCode: initialCurrencyCode,
            initialTimeZoneIdentifier: initialTimeZoneIdentifier
        )

        return JobSetupViewController(viewModel: viewModel)
    }

    static func makePayPeriod(
        draft: JobSetupDraft
    ) -> PayPeriodSetupViewController {
        let viewModel = PayPeriodSetupViewModel(draft: draft)

        return PayPeriodSetupViewController(viewModel: viewModel)
    }

    static func makeReview(
        draft: JobSetupDraft,
        stack: CoreDataStack
    ) -> JobSetupReviewViewController {
        let jobStorage = JobStorage(stack: stack)
        let viewModel = JobSetupReviewViewModel(draft: draft)

        return JobSetupReviewViewController(
            viewModel: viewModel,
            saveJob: { job in
                try jobStorage.save(job)
            }
        )
    }
}
