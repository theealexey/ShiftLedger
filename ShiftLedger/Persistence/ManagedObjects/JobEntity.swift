import Foundation
import CoreData

@objc(JobEntity)
class JobEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var currencyCode: String
    @NSManaged var timeZoneIdentifier: String
    @NSManaged var basePayKind: String?
    @NSManaged var payPeriodKind: String
    @NSManaged var payPeriodAnchorDate: Date?
    @NSManaged var createdAt: Date
    @NSManaged var payRates: NSSet
}
