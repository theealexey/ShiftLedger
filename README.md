# ShiftLedger

ShiftLedger is an iPhone app for hourly and shift workers.

Record the shifts you worked and the pay information you know. ShiftLedger calculates expected gross pay before taxes and deductions, then compares it with the gross amount reported by your employer.

Its core question is:

> **Was I paid correctly?**

The product focuses on transparent, explainable calculations rather than simply tracking hours.

## Product Scope

- Three-step onboarding for one job
- Multiple work types within the job
- Optional work-type names
- Hourly or fixed-per-shift compensation per work type
- Pay-rate history and pay calculation periods
- Stable job time-zone selection
- Add and edit persisted shifts, including overnight shifts
- One optional unpaid break per shift
- Shift validation, job-wide overlap protection, and adjacent shifts
- Expected gross calculation with per-shift breakdowns
- Employer-reported actual gross entry and exact gross-pay difference comparison
- Local Core Data persistence for the job, work types, and shifts
- English and Russian localization

These capabilities are implemented in the current application rather than being future placeholders.

## Tech Stack

- Swift 6
- UIKit with programmatic Auto Layout
- iOS 17+
- async/await at real asynchronous boundaries
- Core Data for local persistence
- String Catalog localization
- Swift Testing for unit, integration, controller, and persistence coverage
- XCTest for UI tests

## Architecture

- Domain models and business rules are independent of UIKit and Core Data.
- Core Data types remain inside the Persistence layer.
- UIKit presentation is built programmatically with dedicated views and view models.
- Dependencies are composed explicitly at the application boundary.

## Status

ShiftLedger is under active development. The current implementation includes the end-to-end path from job setup and persisted shift history through expected-gross calculation, employer-reported gross entry, and paycheck comparison with explainable calculation details.

## Requirements

- iOS 17+
- Xcode with Swift 6 support
