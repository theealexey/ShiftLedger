import Foundation

@MainActor
enum JobSelectionAssembly {
    static func items(from catalog: [JobCatalogEntry]) -> [JobSelectionItem] {
        catalog.map {
            JobSelectionItem(
                id: $0.job.id,
                name: $0.name,
                currencyCode: $0.job.currencyCode,
                timeZoneIdentifier: $0.job.timeZoneIdentifier,
                isArchived: $0.isArchived
            )
        }
    }

    static func make(catalog: [JobCatalogEntry]) -> JobSelectionViewController {
        JobSelectionViewController(items: items(from: catalog))
    }
}
