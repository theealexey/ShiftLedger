import Foundation

@MainActor
enum AddWorkTypeAssembly {
    static func make(job: Job, stack: CoreDataStack) -> AddWorkTypeViewController {
        let storage = JobStorage(stack: stack)
        let viewModel = AddWorkTypeViewModel(
            currencyCode: job.currencyCode,
            saveWorkType: { workType in
                do {
                    return .success(try storage.addWorkType(workType))
                } catch JobStorageError.invalidWorkTypeAddition(_) {
                    return .failure(.invalidWorkType)
                } catch {
                    return .failure(.persistence)
                }
            }
        )

        return AddWorkTypeViewController(viewModel: viewModel)
    }
}
