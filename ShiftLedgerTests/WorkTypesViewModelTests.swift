import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct WorkTypesViewModelTests {
    @Test("Management groups active before archived without changing order within each group")
    func groupsWorkTypes() throws {
        let first = try makeWorkType(1)
        let archived = try makeWorkType(2).archived()
        let last = try makeWorkType(3)
        let viewModel = WorkTypesViewModel(workTypes: [last, archived, first]) { _ in .failure(.generic) }

        #expect(viewModel.sections == [.active([last, first]), .archived([archived])])
        viewModel.reload(workTypes: [archived])
        #expect(viewModel.sections == [.archived([archived])])
        viewModel.reload(workTypes: [])
        #expect(viewModel.sections.isEmpty)
    }

    @Test("Archive calls storage once for the exact active UUID and updates only after success")
    func archiveSuccess() throws {
        let workType = try makeWorkType(1)
        let job = try makeJob(workTypes: [workType])
        let updatedJob = try job.archivingWorkType(id: workType.id)
        var calls: [UUID] = []
        var viewModel: WorkTypesViewModel?
        viewModel = WorkTypesViewModel(workTypes: job.workTypes) { id in
            calls.append(id)
            #expect(viewModel?.workTypes == job.workTypes)
            return .success(updatedJob)
        }
        let model = try #require(viewModel)

        #expect(model.archive(id: workType.id) == .archived(updatedJob))
        #expect(calls == [workType.id])
        #expect(model.workTypes == updatedJob.workTypes)
        #expect(model.archive(id: workType.id) == .ignored)
        #expect(calls.count == 1)
    }

    @Test("Archive failure and invalid target retain visible WorkTypes")
    func archiveFailure() throws {
        let active = try makeWorkType(1)
        let archived = try makeWorkType(2).archived()
        var calls: [UUID] = []
        let model = WorkTypesViewModel(workTypes: [active, archived]) { id in
            calls.append(id)
            return .failure(.generic)
        }

        #expect(model.archive(id: active.id) == .failed)
        #expect(model.archive(id: archived.id) == .ignored)
        #expect(model.archive(id: UUID()) == .ignored)
        #expect(calls == [active.id])
        #expect(model.workTypes == [active, archived])
    }

    private func makeWorkType(_ value: UInt8) throws -> WorkType {
        WorkType(
            id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value)),
            name: "Work \(value)",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(payRates: [
                try PayRate(amount: 100, effectiveFrom: nil)
            ])
        )
    }

    private func makeJob(workTypes: [WorkType]) throws -> Job {
        try Job(
            currencyCode: "USD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: workTypes,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
