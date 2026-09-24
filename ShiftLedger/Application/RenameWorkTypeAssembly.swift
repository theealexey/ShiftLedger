import Foundation

@MainActor
enum RenameWorkTypeAssembly {
    static func make(workType: WorkType, stack: CoreDataStack) -> RenameWorkTypeViewController {
        let storage = JobStorage(stack: stack)
        let viewModel = RenameWorkTypeViewModel(workType: workType) { id, rawName in
            do {
                return .success(try storage.renameWorkType(id: id, to: rawName))
            } catch {
                return .failure(.persistence)
            }
        }
        return RenameWorkTypeViewController(viewModel: viewModel)
    }
}
