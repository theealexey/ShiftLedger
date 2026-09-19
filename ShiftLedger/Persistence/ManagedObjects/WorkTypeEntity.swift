import CoreData
import Foundation

@objc(WorkTypeEntity)
class WorkTypeEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var basePayKind: String
    @NSManaged var job: JobEntity
    @NSManaged var payRates: NSSet?
    @NSManaged var shifts: NSSet?
}
