import Foundation

@MainActor
enum EditShiftAssembly {
    static func make(
        job: Job,
        shift: Shift,
        stack: CoreDataStack
    ) -> EditShiftViewController {
        let shiftStorage = ShiftStorage(stack: stack)
        let viewModel = EditShiftViewModel(
            timeZoneIdentifier: job.timeZoneIdentifier,
            workTypes: job.workTypes,
            shift: shift,
            saveShift: { updatedShift in
                update(updatedShift, jobID: job.id, using: shiftStorage)
            },
            deleteShift: { shiftID in
                delete(shiftID, jobID: job.id, using: shiftStorage)
            }
        )
        return EditShiftViewController(viewModel: viewModel)
    }

    private static func update(
        _ shift: Shift,
        jobID: UUID,
        using storage: ShiftStorage
    ) -> Result<Void, EditShiftSaveFailure> {
        do {
            try storage.update(shift, forJobID: jobID)
            return .success(())
        } catch ShiftStorageError.overlappingShift {
            return .failure(.overlap)
        } catch {
            return .failure(.generic)
        }
    }

    private static func delete(
        _ shiftID: UUID,
        jobID: UUID,
        using storage: ShiftStorage
    ) -> Result<Void, EditShiftDeleteFailure> {
        do {
            try storage.delete(id: shiftID, inJobID: jobID)
            return .success(())
        } catch {
            return .failure(.generic)
        }
    }
}
