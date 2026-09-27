import Foundation

@MainActor
enum WorkTypesAssembly {
    static func make(workTypes: [WorkType], stack: CoreDataStack) -> WorkTypesViewController {
        let storage = JobStorage(stack: stack)
        let viewModel = WorkTypesViewModel(workTypes: workTypes) { id in
            do {
                return .success(try storage.archiveWorkType(id: id))
            } catch {
                return .failure(.generic)
            }
        }
        return WorkTypesViewController(viewModel: viewModel)
    }
}
