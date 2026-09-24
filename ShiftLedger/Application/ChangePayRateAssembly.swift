import Foundation

@MainActor
enum ChangePayRateAssembly {
    static func make(
        job: Job,
        workType: WorkType,
        stack: CoreDataStack
    ) -> ChangePayRateViewController {
        let storage = JobStorage(stack: stack)
        let viewModel = ChangePayRateViewModel(
            workType: workType,
            currencyCode: job.currencyCode,
            timeZoneIdentifier: job.timeZoneIdentifier
        ) { workTypeID, payRate in
            do {
                return .success(try storage.addPayRate(payRate, toWorkTypeID: workTypeID))
            } catch {
                return .failure(.persistence)
            }
        }
        return ChangePayRateViewController(viewModel: viewModel)
    }
}
