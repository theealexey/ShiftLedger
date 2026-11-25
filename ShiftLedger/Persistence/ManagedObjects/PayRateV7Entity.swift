import CoreData
import Foundation

@objc(PayRateV7Entity)
final class PayRateV7Entity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var amount: String
    @NSManaged var effectiveFrom: Date?
    @NSManaged var job: JobEntity
    @NSManaged var workType: WorkTypeEntity?
}
