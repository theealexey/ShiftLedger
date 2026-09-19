import CoreData
import Foundation
import Testing

struct CoreDataV2SchemaTests {
    @Test("Model bundle сохраняет явные V1 и V2, а current указывает на V2")
    func modelBundleContainsExplicitVersions() throws {
        let packageURL = try modelPackageURL()
        let legacyModel = try loadModel(named: "ShiftLedger", from: packageURL)
        let v2Model = try loadModel(named: "ShiftLedgerV2", from: packageURL)
        let currentModel = try #require(NSManagedObjectModel(contentsOf: packageURL))

        #expect(Set(legacyModel.entitiesByName.keys) == [
            "JobEntity",
            "PayRateEntity",
            "ShiftEntity"
        ])
        #expect(legacyModel.entitiesByName["WorkTypeEntity"] == nil)
        #expect(Set(v2Model.entitiesByName.keys) == [
            "JobEntity",
            "PayRateEntity",
            "ShiftEntity",
            "WorkTypeEntity"
        ])
        #expect(currentModel.entitiesByName["WorkTypeEntity"] != nil)
    }

    @Test("V2 содержит минимальную WorkType schema без uniqueness constraint")
    func workTypeSchemaIsAdditiveAndMinimal() throws {
        let model = try loadV2Model()
        let workType = try #require(model.entitiesByName["WorkTypeEntity"])
        let id = try #require(workType.attributesByName["id"])
        let basePayKind = try #require(workType.attributesByName["basePayKind"])

        #expect(Set(workType.attributesByName.keys) == ["id", "basePayKind"])
        #expect(id.attributeType == .UUIDAttributeType)
        #expect(id.isOptional == false)
        #expect(basePayKind.attributeType == .stringAttributeType)
        #expect(basePayKind.isOptional == false)
        #expect(workType.uniquenessConstraints.isEmpty)
    }

    @Test("V2 relationships имеют transitional cardinality и inverses")
    func transitionalRelationshipsMatchContract() throws {
        let model = try loadV2Model()
        let job = try #require(model.entitiesByName["JobEntity"])
        let workType = try #require(model.entitiesByName["WorkTypeEntity"])
        let payRate = try #require(model.entitiesByName["PayRateEntity"])

        let jobWorkTypes = try #require(job.relationshipsByName["workTypes"])
        let workTypeJob = try #require(workType.relationshipsByName["job"])
        let workTypePayRates = try #require(workType.relationshipsByName["payRates"])
        let payRateWorkType = try #require(payRate.relationshipsByName["workType"])

        #expect(jobWorkTypes.isToMany)
        #expect(jobWorkTypes.minCount == 0)
        #expect(jobWorkTypes.deleteRule == .cascadeDeleteRule)
        #expect(jobWorkTypes.inverseRelationship === workTypeJob)

        #expect(workTypeJob.isToMany == false)
        #expect(workTypeJob.isOptional == false)
        #expect(workTypeJob.maxCount == 1)
        #expect(workTypeJob.deleteRule == .nullifyDeleteRule)
        #expect(workTypeJob.inverseRelationship === jobWorkTypes)

        #expect(workTypePayRates.isToMany)
        #expect(workTypePayRates.minCount == 0)
        #expect(workTypePayRates.deleteRule == .cascadeDeleteRule)
        #expect(workTypePayRates.inverseRelationship === payRateWorkType)

        #expect(payRateWorkType.isToMany == false)
        #expect(payRateWorkType.isOptional)
        #expect(payRateWorkType.maxCount == 1)
        #expect(payRateWorkType.deleteRule == .nullifyDeleteRule)
        #expect(payRateWorkType.inverseRelationship === workTypePayRates)
    }

    @Test("V2 сохраняет весь legacy ownership graph")
    func legacyGraphRemainsPresent() throws {
        let model = try loadV2Model()
        let job = try #require(model.entitiesByName["JobEntity"])
        let payRate = try #require(model.entitiesByName["PayRateEntity"])
        let shift = try #require(model.entitiesByName["ShiftEntity"])

        #expect(job.attributesByName["basePayKind"] != nil)
        #expect(job.relationshipsByName["payRates"] != nil)
        #expect(job.relationshipsByName["shifts"] != nil)
        #expect(payRate.relationshipsByName["job"] != nil)
        #expect(shift.relationshipsByName["job"] != nil)
    }

    private func loadV2Model() throws -> NSManagedObjectModel {
        try loadModel(named: "ShiftLedgerV2", from: modelPackageURL())
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
