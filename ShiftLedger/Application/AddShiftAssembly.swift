import Foundation

@MainActor
enum AddShiftAssembly {
    static func make(job: Job, shiftStorage: ShiftStorage) -> AddShiftViewController {
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
