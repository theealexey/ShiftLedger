import CoreData
import Foundation
import Testing

struct CoreDataV3SchemaTests {
    @Test("Model bundle содержит V1, V2 и current V3")
    func modelBundleContainsAllVersionsAndCurrentIsV3() throws {
        let packageURL = try modelPackageURL()
        let v1 = try loadModel(named: "ShiftLedger", from: packageURL)
        let v2 = try loadModel(named: "ShiftLedgerV2", from: packageURL)
        let v3 = try loadModel(named: "ShiftLedgerV3", from: packageURL)
        let current = try #require(NSManagedObjectModel(contentsOf: packageURL))

        #expect(v1.entitiesByName["WorkTypeEntity"] == nil)
        #expect(v2.entitiesByName["ShiftEntity"]?.relationshipsByName["workType"] == nil)
        #expect(v2.entitiesByName["WorkTypeEntity"]?.relationshipsByName["shifts"] == nil)
        #expect(v3.entitiesByName["ShiftEntity"]?.relationshipsByName["workType"] != nil)
        #expect(v3.entitiesByName["WorkTypeEntity"]?.relationshipsByName["shifts"] != nil)
        #expect(current.entityVersionHashesByName == v3.entityVersionHashesByName)
    }

    @Test("V3 Shift.workType — optional to-one Nullify с правильным inverse")
    func shiftWorkTypeRelationshipMatchesContract() throws {
        let model = try loadV3Model()
        let shift = try #require(model.entitiesByName["ShiftEntity"])
        let workType = try #require(model.entitiesByName["WorkTypeEntity"])
        let shiftWorkType = try #require(shift.relationshipsByName["workType"])
        let workTypeShifts = try #require(workType.relationshipsByName["shifts"])

        #expect(shiftWorkType.isToMany == false)
        #expect(shiftWorkType.isOptional)
        #expect(shiftWorkType.maxCount == 1)
        #expect(shiftWorkType.destinationEntity === workType)
        #expect(shiftWorkType.deleteRule == .nullifyDeleteRule)
        #expect(shiftWorkType.inverseRelationship === workTypeShifts)
    }

    @Test("V3 WorkType.shifts — optional to-many Cascade с правильным inverse")
    func workTypeShiftsRelationshipMatchesContract() throws {
        let model = try loadV3Model()
        let shift = try #require(model.entitiesByName["ShiftEntity"])
        let workType = try #require(model.entitiesByName["WorkTypeEntity"])
        let workTypeShifts = try #require(workType.relationshipsByName["shifts"])
        let shiftWorkType = try #require(shift.relationshipsByName["workType"])

        #expect(workTypeShifts.isToMany)
        #expect(workTypeShifts.isOptional)
        #expect(workTypeShifts.minCount == 0)
        #expect(workTypeShifts.destinationEntity === shift)
        #expect(workTypeShifts.deleteRule == .cascadeDeleteRule)
        #expect(workTypeShifts.inverseRelationship === shiftWorkType)
    }

    @Test("V3 сохраняет legacy Shift graph и canonical compensation graph")
    func existingGraphsRemainPresent() throws {
        let model = try loadV3Model()
        let job = try #require(model.entitiesByName["JobEntity"])
        let shift = try #require(model.entitiesByName["ShiftEntity"])
        let workType = try #require(model.entitiesByName["WorkTypeEntity"])
        let payRate = try #require(model.entitiesByName["PayRateEntity"])

        let jobShifts = try #require(job.relationshipsByName["shifts"])
        let shiftJob = try #require(shift.relationshipsByName["job"])
        #expect(jobShifts.isToMany)
        #expect(jobShifts.minCount == 0)
        #expect(jobShifts.deleteRule == .cascadeDeleteRule)
        #expect(jobShifts.inverseRelationship === shiftJob)
        #expect(shiftJob.isToMany == false)
        #expect(shiftJob.isOptional == false)
        #expect(shiftJob.maxCount == 1)
        #expect(shiftJob.deleteRule == .nullifyDeleteRule)

        #expect(job.relationshipsByName["workTypes"]?.inverseRelationship === workType.relationshipsByName["job"])
        #expect(workType.relationshipsByName["payRates"]?.inverseRelationship === payRate.relationshipsByName["workType"])
    }

    private func loadV3Model() throws -> NSManagedObjectModel {
        try loadModel(named: "ShiftLedgerV3", from: modelPackageURL())
    }

    private func modelPackageURL() throws -> URL {
        try #require(
            Bundle.main.url(forResource: "ShiftLedger", withExtension: "momd")
        )
    }

    private func loadModel(
        named name: String,
        from packageURL: URL
    ) throws -> NSManagedObjectModel {
        let modelURL = packageURL
            .appendingPathComponent(name)
            .appendingPathExtension("mom")
        #expect(FileManager.default.fileExists(atPath: modelURL.path))
        return try #require(NSManagedObjectModel(contentsOf: modelURL))
    }
}
