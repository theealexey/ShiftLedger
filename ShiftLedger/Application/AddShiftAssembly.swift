import Foundation

@MainActor
enum AddShiftAssembly {
    static func make(job: Job, stack: CoreDataStack) -> AddShiftViewController {
        let shiftStorage = ShiftStorage(stack: stack)
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: job.timeZoneIdentifier,
            saveShift: { shift in
                do {
                    try shiftStorage.save(shift)
                    return .success(())
                } catch ShiftStorageError.overlappingShift {
                    return .failure(.overlap)
                } catch {
                    return .failure(.generic)
                }
            }
        )

        return AddShiftViewController(viewModel: viewModel)
    }
}
