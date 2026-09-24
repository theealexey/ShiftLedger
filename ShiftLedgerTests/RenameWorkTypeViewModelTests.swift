import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct RenameWorkTypeViewModelTests {
    @Test("Existing and historical names initialize without a presentation placeholder")
    func initialNames() throws {
        let named = try makeWorkType(name: "Lectures")
        let unnamed = try makeWorkType(name: nil)
        let namedModel = RenameWorkTypeViewModel(workType: named) { _, _ in .failure(.persistence) }
        let unnamedModel = RenameWorkTypeViewModel(workType: unnamed) { _, _ in .failure(.persistence) }
        #expect(namedModel.nameText == "Lectures")
        #expect(unnamedModel.nameText.isEmpty)
        #expect(namedModel.canSave == false)
        #expect(unnamedModel.canSave == false)
    }

    @Test("Save enablement uses normalized semantic change, preserving internal spacing and case")
    func enablement() throws {
        let model = RenameWorkTypeViewModel(workType: try makeWorkType(name: "Night Shift")) {
            _, _ in .failure(.persistence)
        }
        model.updateNameText(" \n ")
        #expect(model.canSave == false)
        #expect(model.save() == .invalid)
        model.updateNameText("  Night Shift \n")
        #expect(model.canSave == false)
        #expect(model.save() == .unchanged)
        model.updateNameText("Night  Shift")
        #expect(model.canSave)
        model.updateNameText("night Shift")
        #expect(model.canSave)
    }

    @Test("Save passes raw text and exact UUID, returns updated Job, and blocks duplicates")
    func saveSuccess() throws {
        let workType = try makeWorkType(name: "Lectures")
        let updatedJob = try makeJob(workType: try workType.renamed(to: "Senior   Lectures"))
        var receivedID: UUID?
        var receivedName: String?
        var calls = 0
        let model = RenameWorkTypeViewModel(workType: workType) { id, rawName in
            calls += 1
            receivedID = id
            receivedName = rawName
            return .success(updatedJob)
        }
        model.updateNameText("  Senior   Lectures \n")

        #expect(model.save() == .saved(updatedJob))
        #expect(receivedID == workType.id)
        #expect(receivedName == "  Senior   Lectures \n")
        #expect(model.canSave == false)
        #expect(model.save() == .ignored)
        #expect(calls == 1)
    }

    @Test("Failure retains raw form and permits retry")
    func failureAndRetry() throws {
        let workType = try makeWorkType(name: nil)
        var calls = 0
        let model = RenameWorkTypeViewModel(workType: workType) { _, _ in
            calls += 1
            return .failure(.persistence)
        }
        model.updateNameText("  Exams  ")
        #expect(model.save() == .failed(.persistence))
        #expect(model.nameText == "  Exams  ")
        #expect(model.isSaving == false)
        #expect(model.canSave)
        #expect(model.save() == .failed(.persistence))
        #expect(calls == 2)
    }

    @Test("Reentrant save while persistence is active is ignored")
    func reentrantSaveIgnored() throws {
        let workType = try makeWorkType(name: "Lectures")
        var model: RenameWorkTypeViewModel?
        var nestedResult: RenameWorkTypeSaveResult?
        model = RenameWorkTypeViewModel(workType: workType) { _, _ in
            nestedResult = model?.save()
            return .failure(.persistence)
        }
        let subject = try #require(model)
        subject.updateNameText("Exams")
        #expect(subject.save() == .failed(.persistence))
        #expect(nestedResult == .ignored)
    }

    private func makeWorkType(name: String?) throws -> WorkType {
        WorkType(
            id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            name: name,
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(
                    id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                    amount: 100,
                    effectiveFrom: nil
                )
            ])
        )
    }

    private func makeJob(workType: WorkType) throws -> Job {
        try Job(
            id: UUID(uuid: (0x73, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [workType],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
