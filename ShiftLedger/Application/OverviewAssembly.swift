import Foundation

@MainActor
enum OverviewAssembly {
    static func make(
        job: Job,
        stack: CoreDataStack,
        currentDate: @escaping @MainActor () -> Date = { Date() }
    ) -> OverviewViewController {
        let shiftStorage = ShiftStorage(stack: stack)
        let viewModel = OverviewViewModel(
            job: job,
            loadShiftsForJob: { try shiftStorage.loadAll(forJobID: $0) },
            currentDate: currentDate
        )

        return OverviewViewController(
            viewModel: viewModel,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier
        )
    }
}
