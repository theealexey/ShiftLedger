import Foundation
import CoreData

@objc(ShiftEntity)
class ShiftEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var start: Date
    @NSManaged var end: Date
    @NSManaged var unpaidBreakStart: Date?
    @NSManaged var unpaidBreakEnd: Date?
    @NSManaged var job: JobEntity?
}
