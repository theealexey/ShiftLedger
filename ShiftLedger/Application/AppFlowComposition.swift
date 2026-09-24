import Foundation

@MainActor
struct AppFlowComposition {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
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
            makeWorkTypes: { workTypes in
                WorkTypesViewController(workTypes: workTypes)
            },
            makeAddWorkType: { job in
                AddWorkTypeAssembly.make(job: job, stack: stack)
            },
            makeRenameWorkType: { workType in
                RenameWorkTypeAssembly.make(workType: workType, stack: stack)
            },
            makeChangePayRate: { job, workType in
                ChangePayRateAssembly.make(job: job, workType: workType, stack: stack)
            },
            makeEditShift: { job, shift in
                EditShiftAssembly.make(job: job, shift: shift, stack: stack)
            },
            makeActualGrossEntry: { currencyCode in
                ActualGrossEntryAssembly.make(currencyCode: currencyCode)
            },
            preparePaycheckComparison: { job, period, actualGross in
                let shifts = try ShiftStorage(stack: stack).loadAll()
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
