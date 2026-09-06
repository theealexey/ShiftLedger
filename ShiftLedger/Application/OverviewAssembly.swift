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
            loadShifts: { try shiftStorage.loadAll() },
            currentDate: currentDate
        )

        return OverviewViewController(
            viewModel: viewModel,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier
        )
    }
}
