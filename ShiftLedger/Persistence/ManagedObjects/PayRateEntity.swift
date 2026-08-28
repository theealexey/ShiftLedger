import Foundation
import CoreData

@objc(PayRateEntity)
class PayRateEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var amount: NSDecimalNumber
    @NSManaged var effectiveFrom: Date
    @NSManaged var job: JobEntity
}
