import CoreData
import Foundation

@objc(PayRateAmountMigrationPolicy)
final class PayRateAmountMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource source: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard let legacyNumber = source.value(forKey: "amount") as? NSDecimalNumber else {
            throw PayRateStoreMigrationError.invalidLegacyAmount
        }
        let amount = legacyNumber.decimalValue
        let canonical = try PayRateDecimalCodec.encode(amount)
        guard try PayRateDecimalCodec.decode(canonical) == amount else {
            throw PayRateStoreMigrationError.invalidLegacyAmount
        }
        try super.createDestinationInstances(forSource: source, in: mapping, manager: manager)
        guard let mappingName = mapping.name else { throw PayRateStoreMigrationError.invalidMapping }
        let results = manager.destinationInstances(forEntityMappingName: mappingName, sourceInstances: [source])
        guard results.count == 1, let destination = results.first else {
            throw PayRateStoreMigrationError.invalidMapping
        }
        destination.setValue(canonical, forKey: "amount")
    }
}
