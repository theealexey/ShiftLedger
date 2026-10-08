import Foundation

@MainActor
enum AppLaunchDestination: Equatable {
    case onboarding
    case main(Job)
    case jobSelection([JobCatalogEntry])
}

@MainActor
struct AppLaunchResolution {
    let composition: AppFlowComposition
    let destination: AppLaunchDestination
}

@MainActor
final class AppLaunchResolver {
    private let loadCoreDataStack: @MainActor () async throws -> CoreDataStack
    private let arguments: [String]

    init(
        loadCoreDataStack: @escaping @MainActor () async throws -> CoreDataStack = {
            try await CoreDataStack.load()
        },
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.loadCoreDataStack = loadCoreDataStack
        self.arguments = arguments
    }

    func resolve() async throws -> AppLaunchResolution {
        try prepareLaunchStateForUITesting()

        let stack = try await loadCoreDataStack()
        try Task.checkCancellation()

        let catalog = try loadInitialCatalog(from: stack)
        try Task.checkCancellation()
        let activeJobs = catalog.filter { !$0.isArchived }
        let destination: AppLaunchDestination
        if catalog.isEmpty {
            destination = .onboarding
        } else if activeJobs.count == 1, let entry = activeJobs.first {
            destination = .main(entry.job)
        } else {
            destination = .jobSelection(catalog)
        }

        return AppLaunchResolution(
            composition: AppFlowComposition(stack: stack),
            destination: destination
        )
    }

    private func prepareLaunchStateForUITesting() throws {
#if DEBUG
        if arguments.contains("-ui-testing-reset-store") {
            try CoreDataStack.resetPersistentStoreForUITesting()
        }
#endif
    }

    private func loadInitialCatalog(from stack: CoreDataStack) throws -> [JobCatalogEntry] {
        let jobStorage = JobStorage(stack: stack)
        let catalog = try jobStorage.loadCatalog()

#if DEBUG
        if arguments.contains("-ui-testing-seed-job"), catalog.isEmpty {
            let job = try Job(
                currencyCode: "SEK",
                timeZoneIdentifier: "Europe/Stockholm",
                basePayBasis: .hourly,
                payCalculationCycle: .perShift,
                payRates: [
                    try PayRate(
                        amount: 100,
                        effectiveFrom: nil
                    )
                ],
                createdAt: Date(timeIntervalSinceReferenceDate: 0)
            )
            try jobStorage.save(job)
            return try jobStorage.loadCatalog()
        }
#endif

        return catalog
    }
}
