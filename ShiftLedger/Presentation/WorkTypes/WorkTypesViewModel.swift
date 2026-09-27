import Foundation

enum WorkTypesArchiveFailure: Error {
    case generic
}

enum WorkTypesArchiveResult: Equatable {
    case archived(Job)
    case failed
    case ignored
}

@MainActor
final class WorkTypesViewModel {
    enum Section: Equatable {
        case active([WorkType])
        case archived([WorkType])

        var workTypes: [WorkType] {
            switch self {
            case let .active(workTypes), let .archived(workTypes): workTypes
            }
        }
    }

    private(set) var workTypes: [WorkType]
    private let archiveWorkType: (UUID) -> Result<Job, WorkTypesArchiveFailure>

    init(
        workTypes: [WorkType],
        archiveWorkType: @escaping (UUID) -> Result<Job, WorkTypesArchiveFailure>
    ) {
        self.workTypes = workTypes
        self.archiveWorkType = archiveWorkType
    }

    var sections: [Section] {
        let active = workTypes.filter { !$0.isArchived }
        let archived = workTypes.filter(\.isArchived)
        var result: [Section] = []
        if !active.isEmpty { result.append(.active(active)) }
        if !archived.isEmpty { result.append(.archived(archived)) }
        return result
    }

    func reload(workTypes: [WorkType]) {
        self.workTypes = workTypes
    }

    func archive(id: UUID) -> WorkTypesArchiveResult {
        guard workTypes.contains(where: { $0.id == id && !$0.isArchived }) else {
            return .ignored
        }
        switch archiveWorkType(id) {
        case let .success(job):
            workTypes = job.workTypes
            return .archived(job)
        case .failure:
            return .failed
        }
    }
}
