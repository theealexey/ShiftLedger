import Foundation

@MainActor
final class JobNameSetupViewModel {
    private(set) var draft: JobSetupDraft

    init(draft: JobSetupDraft) {
        self.draft = draft
    }

    var canContinue: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func updateName(_ value: String) {
        draft.name = value
    }
}
