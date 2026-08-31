# ShiftLedger

ShiftLedger is an iPhone app for people who are paid by the hour or by the shift.

Users record the shifts they actually worked and the pay rules they know. ShiftLedger independently calculates the amount they should expect to receive **before taxes and deductions**, then lets them compare that result with the gross amount reported by their employer.

The product is built around one question:

> **Was I paid correctly?**

And one core principle:

> **No unexplained numbers.**

Every calculated amount should be deterministic, auditable, and traceable back to the hours, rates, periods, and pay rules that produced it.

ShiftLedger is a pay-verification tool. It is not payroll, tax, accounting, or legal software.

---

## Planned v1 Scope

The first version is designed around one job and local, offline-first data.

Planned v1 capabilities include:

- one job;
- selectable currency;
- a fixed job time zone stored by stable IANA identifier;
- hourly or fixed-per-shift base pay;
- per-shift, weekly, biweekly, or calendar-month pay cycles;
- pay-rate history;
- actual worked shifts;
- overnight shifts;
- one unpaid break per shift;
- weekly overtime rules;
- fixed night premiums;
- increased pay for selected weekdays;
- expected gross-pay calculation;
- manual entry of the employer-reported gross amount;
- expected-vs-actual comparison;
- an explainable calculation breakdown;
- pay-period history;
- local persistence.

### Explicitly out of scope for v1

The first version does **not** include:

- taxes or withholding calculations;
- backend accounts or authentication;
- CloudKit synchronization;
- OCR, AI, or camera-based payslip scanning;
- schedule import or third-party integrations;
- Apple Watch or widgets;
- country-specific payroll engines;
- social features;
- cross-device synchronization.

The comparison is intentionally based on **gross pay before taxes and deductions**.

---

## Current Status

The current milestone establishes the application foundation and the complete flow from first launch to persisted shift entry.

Implemented:

- three-step onboarding;
- hourly or fixed-per-shift base-pay selection;
- pay-cycle selection;
- currency selection;
- stable job time-zone selection;
- `Job` creation and local persistence;
- production Core Data startup;
- persisted `Job` restoration after relaunch;
- startup failure handling, retry, and cancellation;
- `Add Shift` screen;
- `Shift` validation;
- overnight shifts;
- one optional unpaid break;
- 48-hour maximum real shift duration;
- half-open overlap detection;
- adjacent shifts without overlap;
- real `Shift` persistence;
- successful Add Shift save/reset flow;
- English and Russian localization;
- unit, integration, controller, persistence, and UI startup regression coverage.

The next major milestone is the **calculation engine**. It is not implemented yet.

It will cover:

- paid duration;
- applicable `PayRate` selection by date;
- hourly vs fixed-per-shift base pay;
- pay-period boundaries;
- expected gross pay;
- employer-reported gross input;
- expected-vs-actual difference;
- calculation breakdown;
- calculation/pay-period history.

Overtime, night, and weekday premium calculation will be added only after their business rules are fully formalized and tested.

---

## Technical Foundation

- Swift 6
- UIKit
- Core Data
- iOS 17+
- programmatic UI
- Auto Layout
- no Storyboards or `IBOutlet`
- offline-first local persistence
- English and Russian localization

The project deliberately favors **production-quality code without architecture for architecture's sake**.

An abstraction is introduced only when it solves a concrete responsibility, dependency, or testability problem.

---

## Architecture

The architecture is intentionally proportional to the current product.

### Application

`SceneDelegate` owns:

- application startup;
- Core Data stack lifetime;
- startup routing;
- root navigation composition.

Assemblies construct concrete screens and inject concrete dependencies.

Assemblies do **not** choose the application's startup state, create global dependency registries, or act as service locators.

There is currently no Coordinator, Router, AppContainer, Repository protocol, or Use Case layer because the implemented flows do not require them yet.

These abstractions may be introduced later if a real responsibility justifies them.

### Presentation

UIKit responsibilities are separated deliberately:

- `UIView` owns subviews, hierarchy, layout, and Auto Layout constraints;
- `UIViewController` owns lifecycle, user events, presentation, and navigation callbacks;
- ViewModels own screen state, validation orchestration, and presentation-facing actions;
- Presentation does not know about Core Data implementation details.

Presentation must not receive:

- `NSManagedObjectContext`;
- `NSManagedObject`;
- `NSPersistentContainer`;
- persistence-specific models.

### Domain

Domain contains pure value models, invariants, and business rules.

It does not import UIKit or Core Data.

Pure Domain code is not isolated to `MainActor`.

Current Domain concepts include:

- `Job`;
- `PayRate`;
- `Shift`;
- `UnpaidBreak`;
- `LocalDate`;
- pay-period models;
- typed validation errors.

### Persistence

Core Data is treated as a persistence and object-graph framework, not as the Domain model.

Rules:

- `NSManagedObjectContext` stays inside the persistence layer;
- `NSManagedObject` subclasses never reach Presentation or Domain;
- persisted objects are reconstructed into Domain values;
- reconstructed data is validated again through Domain invariants;
- persistence corruption is represented explicitly;
- persistence failures use typed errors;
- the application has one production `CoreDataStack` owner per scene.

The current v1 persistence layer uses the main `viewContext` synchronously under `@MainActor`.

A background context or async repository will be introduced only when there is a real workload that requires one, such as a heavy import, synchronization, or expensive background processing.

---

## Domain Conventions

### Time

Time handling is explicit because shift and pay calculations are time-zone sensitive.

- `Date` represents an absolute instant;
- `LocalDate` represents a Gregorian calendar date without a time zone;
- each `Job` stores a stable IANA time-zone identifier;
- device time-zone changes must not reinterpret historical job data;
- elapsed shift duration is calculated from absolute instants;
- DST transitions therefore reflect real elapsed time rather than naïve wall-clock subtraction.

### Shift intervals

Shift overlap uses half-open interval semantics:

```text
[start, end)
```

Therefore:

- start < end is required;
- a shift may not exceed 48 real hours;
- one optional unpaid break is allowed;
- the break must be valid and contained inside the shift;
- overlapping shifts are rejected;
- adjacent shifts are valid.

For example:

```text
08:00–17:00
17:00–22:00
```

is valid because the two shifts touch but do not overlap.

### Pay rates

A Job owns its pay-rate history.

Current invariants include:

- at least one PayRate;
- exactly one initial rate with `effectiveFrom == nil`;
- dated rates have unique effective dates;
- PayRate identifiers are unique within a Job;
- pay-rate amounts must be positive.

Money is represented with `Decimal`, not binary floating-point arithmetic.

ShiftLedger does not perform currency conversion.

---

## Concurrency

Concurrency is introduced only where there is a real asynchronous boundary.

Current rules:

- pure Domain code remains nonisolated;
- UIKit and screen ViewModels are MainActor-bound where appropriate;
- application assemblies are MainActor-bound;
- main-context Core Data storage is MainActor-bound;
- startup work is owned and cancellable;
- cancellation is checked before stale startup state can replace current UI;
- structured concurrency is preferred.

The project does not use `Task.detached`, `@unchecked Sendable`, or `nonisolated` as compiler-silencing escape hatches.

Synchronous work stays synchronous until there is a real reason to introduce an async boundary.

---

## Error Handling

Errors are part of the architecture rather than arbitrary strings passed between layers.

Project rules:

- Domain errors are typed;
- persistence errors are typed;
- Presentation maps technical failures into product-facing states and messages;
- raw system errors are not displayed directly to users;
- `localizedDescription` is not used as a Domain or persistence error contract;
- invalid persisted data is treated explicitly as corruption.

Production code avoids:

- force unwraps;
- `try!`;
- `as!`;
- `fatalError`;
- empty catch blocks.

---

## Localization and Regional Formatting

ShiftLedger currently supports English and Russian.

Language and regional formatting are treated as separate concerns.

- application-language locale is used for localized display names;
- the user’s regional locale controls date/time conventions such as 12-hour vs 24-hour formatting;
- `Job.timeZoneIdentifier` determines the time zone in which shift instants are displayed;
- Foundation/ICU is used for localized time-zone exemplar-city names rather than city-specific hard-coded branches.

A change in the device’s current time zone must not change the historical meaning of stored job or shift data.

---

## Accessibility and UIKit

The UI is built with native UIKit behavior rather than custom interaction systems wherever possible.

Current principles:

- programmatic UIKit;
- no Storyboards;
- layout belongs to dedicated UIView subclasses;
- ViewControllers do not build large view hierarchies;
- native controls are preferred;
- Dynamic Type is treated as a product requirement;
- VoiceOver semantics are considered during screen implementation;
- accessibility identifiers are added narrowly for stable UI regression tests and do not replace user-facing accessibility labels.

---

## Testing Strategy

Tests verify behavior, invariants, persistence, and regressions rather than only happy paths.

Current coverage includes:

- Domain validation and invalid inputs;
- Job, PayRate, LocalDate, and Shift invariants;
- DST and date-conversion behavior;
- overlap and adjacency semantics;
- Core Data mapping;
- typed corruption paths;
- missing required relationship corruption;
- real SQLite persistence;
- persistence stack reopening;
- ViewModel state transitions;
- controller save/failure behavior;
- onboarding navigation regressions;
- onboarding retry behavior;
- startup failure, retry, and cancellation;
- fresh-install startup routing;
- persisted-Job relaunch routing;
- Add Shift persistence;
- duplicate-save regression protection.

Persistence tests use isolated stores.

UI tests use narrow DEBUG-only reset/seed hooks. Those hooks are excluded from Release builds.

Tests should remain:

- fast;
- deterministic;
- independent;
- focused on observable behavior.

A runtime bug is not considered fully fixed until a focused regression test is added when practical.

---

## Development Principles

The following rules were established during implementation and code review.

1. Correctness before abstraction

   Business rules are formalized before architectural layers are added around them.

2. Architecture must earn its existence

   Protocols, factories, repositories, use cases, coordinators, and containers are introduced only when they solve a concrete problem.

3. One clear owner per responsibility

   UI layout, screen coordination, Domain rules, persistence, and application composition have distinct owners.

4. Persistence implementation stays private

   Managed objects and managed-object contexts do not leak across architectural boundaries.

5. Time semantics must be explicit

   Absolute instants, calendar dates, and job time zones are different concepts and are modeled separately.

6. Money must remain explainable

   Every final amount must eventually be traceable to source shifts, rates, periods, and pay rules.

7. No decorative async

   Synchronous operations remain synchronous until a genuine asynchronous boundary exists.

8. Test infrastructure must not contaminate Release

   UI-test reset and seed behavior is compile-time DEBUG-only.

9. Regression bugs get regression tests

   Runtime defects found during review are captured with focused tests before a milestone is considered complete.

10. Small, verified commits

    Changes are grouped by responsibility and committed only after the relevant build/test gate passes.

11. Scope discipline

    Features outside the current milestone are not implemented preemptively.

12. Production quality without overengineering

    The goal is code that can be explained, tested, changed, and defended in code review — not the largest possible architecture diagram.

---

## Next Milestone: Calculation Engine

The next implementation phase will turn persisted shifts and pay configuration into explainable expected gross pay.

The work should proceed in this order:

1. paid shift duration;
2. applicable PayRate resolution;
3. hourly and fixed-per-shift base-pay calculation;
4. pay-period boundary calculation;
5. expected gross aggregation;
6. employer-reported gross input;
7. expected-vs-actual comparison;
8. detailed calculation breakdown;
9. pay-period history;
10. overtime, night, and weekday premium rules once their exact business semantics are finalized.

The calculation engine must remain:

- deterministic;
- testable;
- independent of UIKit;
- independent of Core Data implementation details;
- capable of explaining every amount it produces.
