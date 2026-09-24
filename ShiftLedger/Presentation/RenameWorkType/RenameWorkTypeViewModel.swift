import Foundation

enum RenameWorkTypeSaveFailure: Error, Equatable {
    case persistence
}

enum RenameWorkTypeSaveResult: Equatable {
    case saved(Job)
    case failed(RenameWorkTypeSaveFailure)
    case invalid
    case unchanged
    case ignored
}

@MainActor
final class RenameWorkTypeViewModel {
    let workType: WorkType
    private(set) var nameText: String
    private(set) var isSaving = false

    private let saveName: (UUID, String) -> Result<Job, RenameWorkTypeSaveFailure>

    init(
        workType: WorkType,
        saveName: @escaping (UUID, String) -> Result<Job, RenameWorkTypeSaveFailure>
    ) {
        self.workType = workType
        nameText = workType.name ?? ""
        self.saveName = saveName
    }

    var canSave: Bool {
        guard let normalizedName = WorkTypeInputParser.normalizedName(nameText) else {
            return false
        }
        let originalName = WorkTypeInputParser.normalizedName(workType.name ?? "")
        return normalizedName != originalName && isSaving == false
    }

    func updateNameText(_ value: String) {
        nameText = value
    }

    func save() -> RenameWorkTypeSaveResult {
        guard isSaving == false else { return .ignored }
        guard let normalizedName = WorkTypeInputParser.normalizedName(nameText) else {
            return .invalid
        }
        guard normalizedName != WorkTypeInputParser.normalizedName(workType.name ?? "") else {
            return .unchanged
        }

        isSaving = true
        switch saveName(workType.id, nameText) {
        case let .success(job):
            return .saved(job)
        case let .failure(failure):
            isSaving = false
            return .failed(failure)
        }
    }
}
