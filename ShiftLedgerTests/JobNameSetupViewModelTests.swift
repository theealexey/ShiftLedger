import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct JobNameSetupViewModelTests {
    @Test("Пустое имя не позволяет продолжить")
    func emptyNameIsInvalid() {
        let viewModel = JobNameSetupViewModel(draft: makeDraft(name: ""))

        #expect(viewModel.canContinue == false)
    }

    @Test("Пробелы и переводы строк не позволяют продолжить")
    func whitespaceOnlyNameIsInvalid() {
        let viewModel = JobNameSetupViewModel(draft: makeDraft(name: " \n\t "))

        #expect(viewModel.canContinue == false)
    }

    @Test("Непустое имя позволяет продолжить")
    func validNameIsValid() {
        let viewModel = JobNameSetupViewModel(draft: makeDraft(name: "Karolinska Hospital"))

        #expect(viewModel.canContinue)
    }

    @Test("Внешние пробелы не меняют валидность имени")
    func leadingAndTrailingSpacesAllowContinue() {
        let viewModel = JobNameSetupViewModel(draft: makeDraft(name: "  Karolinska Hospital  "))

        #expect(viewModel.canContinue)
        #expect(viewModel.draft.name == "  Karolinska Hospital  ")
    }

    @Test("Изменение имени меняет только name")
    func updateNameMutatesOnlyName() throws {
        let draft = try makeDraftFromCompletedPreviousSteps()
        let viewModel = JobNameSetupViewModel(draft: draft)

        viewModel.updateName("  Karolinska Hospital  ")

        #expect(viewModel.draft.name == "  Karolinska Hospital  ")
        #expect(viewModel.draft.hourlyRateText == draft.hourlyRateText)
        #expect(viewModel.draft.currencyCode == draft.currencyCode)
        #expect(viewModel.draft.timeZoneIdentifier == draft.timeZoneIdentifier)
        #expect(viewModel.draft.payCalculationCycleKind == draft.payCalculationCycleKind)
        #expect(viewModel.draft.payPeriodAnchorDate == draft.payPeriodAnchorDate)
    }

    @Test("Состояние шагов 1 и 2 сохраняется после изменения имени")
    func preservesCompletedPreviousSteps() throws {
        let anchor = try LocalDate(year: 2026, month: 8, day: 30)
        let draft = JobSetupDraft(
            name: "",
            hourlyRateText: "24.50",
            currencyCode: "AUD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycleKind: .biweekly,
            payPeriodAnchorDate: anchor
        )
        let viewModel = JobNameSetupViewModel(draft: draft)

        viewModel.updateName("Karolinska Hospital")

        #expect(viewModel.canContinue)
        #expect(viewModel.draft == JobSetupDraft(
            name: "Karolinska Hospital",
            hourlyRateText: "24.50",
            currencyCode: "AUD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycleKind: .biweekly,
            payPeriodAnchorDate: anchor
        ))
    }

    private func makeDraft(name: String) -> JobSetupDraft {
        JobSetupDraft(
            name: name,
            hourlyRateText: "24.50",
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycleKind: .calendarMonthly,
            payPeriodAnchorDate: nil
        )
    }

    private func makeDraftFromCompletedPreviousSteps() throws -> JobSetupDraft {
        let anchor = try LocalDate(year: 2026, month: 8, day: 30)
        return JobSetupDraft(
            name: "",
            hourlyRateText: "24.50",
            currencyCode: "AUD",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycleKind: .biweekly,
            payPeriodAnchorDate: anchor
        )
    }
}
