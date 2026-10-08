import Foundation

@MainActor
enum WorkTypesAssembly {
    static func make(job: Job, stack: CoreDataStack) -> WorkTypesViewController {
        let storage = JobStorage(stack: stack)
        let viewModel = WorkTypesViewModel(workTypes: job.workTypes) { id in
            do {
                return .success(try storage.archiveWorkType(id: id, inJobID: job.id))
            } catch {
                return .failure(.generic)
            }
        }
        return WorkTypesViewController(viewModel: viewModel)
    }
}
