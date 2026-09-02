# ShiftLedger

ShiftLedger is an iPhone app for hourly and shift workers.

Record the shifts you worked and the pay information you know. ShiftLedger is designed to calculate expected gross pay before taxes and deductions, then compare it with the gross amount reported by your employer.

Its core question is:

> **Was I paid correctly?**

The product focuses on transparent, explainable calculations rather than simply tracking hours.

## Product Scope

- Three-step onboarding for one job
- Hourly or fixed-per-shift base pay
- Pay-rate history and pay periods
- Stable job time-zone selection
- Worked shifts, including overnight shifts
- One optional unpaid break per shift
- Shift validation, overlap protection, and adjacent shifts
- Local persistence for jobs and shifts
- English and Russian localization

The application foundation and shift-entry flow are implemented. Expected-pay calculation, employer comparison, and calculation breakdowns are still under development.

## Tech Stack

- Swift 6
- UIKit with programmatic Auto Layout
- Core Data for local persistence
- Swift concurrency at real asynchronous boundaries
- XCTest-based unit, integration, controller, persistence, and UI coverage

## Architecture

- Domain models and business rules are independent of UIKit and Core Data.
- Core Data types remain inside the Persistence layer.
- UIKit presentation is built programmatically with dedicated views and view models.
- Dependencies are composed explicitly at the application boundary.

## Status

ShiftLedger is under active development. The application foundation is complete, including onboarding, production startup, persisted job restoration, Add Shift, validation, and real shift persistence. The next development area is the payroll calculation engine. Employer-reported gross comparison and explainable pay-period results will follow after it.

## Requirements

- iOS 17+
- Xcode with Swift 6 support
