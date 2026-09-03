import Foundation

@MainActor
enum AddShiftAssembly {
    static func make(job: Job, stack: CoreDataStack) -> AddShiftViewController {
        let shiftStorage = ShiftStorage(stack: stack)
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: job.timeZoneIdentifier,
            saveShift: { shift in
                saveShift(shift, using: shiftStorage)
            }
        )

        return AddShiftViewController(viewModel: viewModel)
    }

    private static func saveShift(
        _ shift: Shift,
        using shiftStorage: ShiftStorage
    ) -> Result<Void, AddShiftSaveFailure> {
        do {
            try shiftStorage.save(shift)
            return .success(())
        } catch ShiftStorageError.overlappingShift {
            return .failure(.overlap)
        } catch {
            return .failure(.generic)
        }
    }
}
