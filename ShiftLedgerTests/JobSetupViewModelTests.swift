import Testing
@testable import ShiftLedger

@MainActor
struct JobSetupViewModelTests {
    @Test("Начальный код валюты сохраняется")
    func preservesInitialCurrencyCode() {
        let viewModel = makeViewModel()

        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Начальный идентификатор зоны времени сохраняется")
    func preservesInitialTimeZoneIdentifier() {
        let viewModel = makeViewModel()

        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
    }

    @Test("Пустое имя не позволяет продолжить")
    func emptyNameDisablesContinue() {
        let viewModel = makeViewModel()

        #expect(viewModel.canContinue == false)
    }

    @Test("Имя из пробелов и переводов строк не позволяет продолжить")
    func whitespaceOnlyNameDisablesContinue() {
        let viewModel = makeViewModel()
        viewModel.updateName(" \n\t ")

        #expect(viewModel.canContinue == false)
    }

    @Test("Обычное имя позволяет продолжить")
    func validNameEnablesContinue() {
        let viewModel = makeViewModel()
        viewModel.updateName("Clinic")

        #expect(viewModel.canContinue)
    }

    @Test("Имя с внешними пробелами сохраняется без нормализации")
    func preservesUnnormalizedNameWhileAllowingContinue() {
        let viewModel = makeViewModel()
        viewModel.updateName("  Clinic  ")

        #expect(viewModel.draft.name == "  Clinic  ")
        #expect(viewModel.canContinue)
    }

    @Test("updateName обновляет draft")
    func updatesNameInDraft() {
        let viewModel = makeViewModel()

        viewModel.updateName("Night clinic")

        #expect(viewModel.draft.name == "Night clinic")
    }

    @Test("Выбор валюты обновляет draft")
    func updatesCurrencyInDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectCurrency(code: "SEK"))
        #expect(viewModel.draft.currencyCode == "SEK")
    }

    @Test("Выбор зоны времени обновляет draft")
    func updatesTimeZoneInDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectTimeZone(identifier: "Europe/Helsinki"))
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Helsinki")
    }

    @Test("Некорректная валюта отклоняется без изменения draft")
    func rejectsInvalidCurrencyWithoutChangingDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectCurrency(code: "EURO") == false)
        #expect(viewModel.draft.currencyCode == "EUR")
    }

    @Test("Некорректная зона времени отклоняется без изменения draft")
    func rejectsInvalidTimeZoneWithoutChangingDraft() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectTimeZone(identifier: "GMT+2") == false)
        #expect(viewModel.draft.timeZoneIdentifier == "Europe/Stockholm")
    }

    private func makeViewModel() -> JobSetupViewModel {
        JobSetupViewModel(
            initialCurrencyCode: "EUR",
            initialTimeZoneIdentifier: "Europe/Stockholm"
        )
    }
}
