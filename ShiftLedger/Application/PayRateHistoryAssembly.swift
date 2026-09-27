import Foundation

@MainActor
enum PayRateHistoryAssembly {
    static func make(job: Job, workType: WorkType) -> PayRateHistoryViewController {
        PayRateHistoryViewController(
            viewModel: PayRateHistoryViewModel(
                workType: workType,
                currencyCode: job.currencyCode,
                timeZoneIdentifier: job.timeZoneIdentifier
            )
        )
    }
}
