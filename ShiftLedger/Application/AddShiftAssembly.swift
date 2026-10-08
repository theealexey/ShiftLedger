import Foundation

@MainActor
enum AddShiftAssembly {
    static func make(job: Job, stack: CoreDataStack) -> AddShiftViewController {
        let shiftStorage = ShiftStorage(stack: stack)
        let viewModel = AddShiftViewModel(
            jobID: job.id,
            timeZoneIdentifier: job.timeZoneIdentifier,
            workTypes: job.workTypes,
            saveShift: { shift in
                saveShift(shift, jobID: job.id, using: shiftStorage)
            }
        )

        return AddShiftViewController(viewModel: viewModel)
    }

    private static func saveShift(
        _ shift: Shift,
        jobID: UUID,
        using shiftStorage: ShiftStorage
    ) -> Result<Void, AddShiftSaveFailure> {
        do {
            try shiftStorage.save(shift, forJobID: jobID)
            return .success(())
        } catch ShiftStorageError.overlappingShift {
            return .failure(.overlap)
        } catch {
            return .failure(.generic)
        }
    }
}
