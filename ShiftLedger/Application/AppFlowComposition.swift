import Foundation

enum JobSelectionError: Error {
    case jobNotFound(jobID: UUID)
    case jobArchived(jobID: UUID)
}

@MainActor
struct AppFlowComposition {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func loadJobSelectionItems() throws -> [JobSelectionItem] {
        JobSelectionAssembly.items(from: try JobStorage(stack: stack).loadCatalog())
    }

    func resolveSelectedJob(id: UUID) throws -> Job {
        let catalog = try JobStorage(stack: stack).loadCatalog()
        guard let entry = catalog.first(where: { $0.job.id == id }) else {
            throw JobSelectionError.jobNotFound(jobID: id)
        }
        guard !entry.isArchived else {
            throw JobSelectionError.jobArchived(jobID: id)
        }
        return entry.job
    }

    func makeOnboardingDependencies() -> OnboardingCoordinator.Dependencies {
        OnboardingCoordinator.Dependencies(
            makeJobSetup: {
                JobSetupAssembly.makeStart(
                    initialCurrencyCode: Locale.autoupdatingCurrent.currency?.identifier ?? "USD",
                    initialTimeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
                )
            },
            makePayPeriod: { draft in
                JobSetupAssembly.makePayPeriod(draft: draft)
            },
            makeReview: { draft in
                JobSetupAssembly.makeReview(draft: draft, stack: stack)
            }
        )
    }

    func makeMainDependencies() -> MainCoordinator.Dependencies {
        MainCoordinator.Dependencies(
            makeOverview: { job in
                OverviewAssembly.make(job: job, stack: stack)
            },
            makeAddShift: { job in
                AddShiftAssembly.make(job: job, stack: stack)
            },
            makeWorkTypes: { job in
                WorkTypesAssembly.make(job: job, stack: stack)
            },
            makeAddWorkType: { job in
                AddWorkTypeAssembly.make(job: job, stack: stack)
            },
            makeRenameWorkType: { job, workType in
                RenameWorkTypeAssembly.make(job: job, workType: workType, stack: stack)
            },
            makeChangePayRate: { job, workType in
                ChangePayRateAssembly.make(job: job, workType: workType, stack: stack)
            },
            makePayRateHistory: { job, workType in
                PayRateHistoryAssembly.make(job: job, workType: workType)
            },
            makeEditShift: { job, shift in
                EditShiftAssembly.make(job: job, shift: shift, stack: stack)
            },
            makeActualGrossEntry: { currencyCode in
                ActualGrossEntryAssembly.make(currencyCode: currencyCode)
            },
            preparePaycheckComparison: { job, period, actualGross in
                let shifts = try ShiftStorage(stack: stack).loadAll(forJobID: job.id)
                return try job.paycheckComparison(
                    for: period,
                    actualGross: actualGross,
                    from: shifts
                )
            },
            makePaycheckResult: { comparison, job in
                PaycheckResultAssembly.make(
                    comparison: comparison,
                    currencyCode: job.currencyCode,
                    timeZoneIdentifier: job.timeZoneIdentifier,
                    workTypes: job.workTypes
                )
            }
        )
    }
}
