import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct AddWorkTypeViewModelTests {
    private let workTypeID = UUID(uuid: (0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let payRateID = UUID(uuid: (0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))

    @Test("Пустое или пробельное название не позволяет сохранить", arguments: ["", "  \n "])
    func invalidNameDisablesSave(_ name: String) {
        let viewModel = makeViewModel()
        viewModel.updateNameText(name)
        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateAmountText("24.50")

        #expect(viewModel.normalizedName == nil)
        #expect(viewModel.canSave == false)
    }

    @Test("Название нормализуется только по краям")
    func normalizesNameWithoutChangingContent() {
        let viewModel = makeViewModel()
        viewModel.updateNameText("  Проверка  Д/З!  ")

        #expect(viewModel.normalizedName == "Проверка  Д/З!")
    }

    @Test("Без базы, с нулевой или некорректной суммой сохранение запрещено")
    func incompletePayInputDisablesSave() {
        let viewModel = makeViewModel()
        viewModel.updateNameText("Lectures")
        viewModel.updateAmountText("24.50")
        #expect(viewModel.canSave == false)

        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateAmountText("0")
        #expect(viewModel.canSave == false)

        viewModel.updateAmountText("1e3")
        #expect(viewModel.amount == nil)
        #expect(viewModel.canSave == false)
    }

    @Test("Локальный десятичный разделитель сохраняет точный Decimal")
    func parsesLocaleDecimalExactly() {
        let viewModel = makeViewModel(locale: Locale(identifier: "ru_RU"))
        viewModel.updateNameText("Лекции")
        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateAmountText("17,125")

        #expect(viewModel.amount == Decimal(string: "17.125"))
        #expect(viewModel.canSave)
    }

    @Test("Смена базы очищает сумму, повторный выбор сохраняет её")
    func basisSelectionClearsOnlyWhenChanged() {
        let viewModel = makeViewModel()
        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateAmountText("100")
        viewModel.selectBasePayBasis(.hourly)
        #expect(viewModel.amountText == "100")

        viewModel.selectBasePayBasis(.fixedPerShift)
        #expect(viewModel.amountText.isEmpty)
    }

    @Test("WorkType и начальная ставка используют точные внедрённые данные")
    func makesExactWorkTypeAndInitialPayRate() throws {
        let viewModel = makeViewModel()
        viewModel.updateNameText("  Лекции  ")
        viewModel.selectBasePayBasis(.hourly)
        viewModel.updateAmountText("17.125")

        let workType = try viewModel.makeWorkType()
        let payRate = try #require(workType.payRates.first)

        #expect(workType.id == workTypeID)
        #expect(workType.name == "Лекции")
        #expect(workType.basePayBasis == .hourly)
        #expect(workType.payRates.count == 1)
        #expect(payRate.id == payRateID)
        #expect(payRate.amount == Decimal(string: "17.125"))
        #expect(payRate.effectiveFrom == nil)
    }

    @Test("Успешное сохранение возвращает точный Job и блокирует дубликат")
    func successfulSaveReturnsJobAndBlocksDuplicate() throws {
        let updatedJob = try makeUpdatedJob()
        var saveCalls = 0
        let viewModel = makeViewModel { _ in
            saveCalls += 1
            return .success(updatedJob)
        }
        makeValid(viewModel)

        #expect(viewModel.save() == .saved(updatedJob))
        #expect(viewModel.isSaving)
        #expect(viewModel.save() == .ignored)
        #expect(saveCalls == 1)
    }

    @Test("Ошибка persistence сохраняет форму и разрешает повтор")
    func persistenceFailurePreservesFormAndAllowsRetry() throws {
        let updatedJob = try makeUpdatedJob()
        var saveCalls = 0
        let viewModel = makeViewModel { _ in
            saveCalls += 1
            return saveCalls == 1 ? .failure(.persistence) : .success(updatedJob)
        }
        makeValid(viewModel)

        #expect(viewModel.save() == .failed(.persistence))
        #expect(viewModel.nameText == "Exams")
        #expect(viewModel.basePayBasis == .fixedPerShift)
        #expect(viewModel.amountText == "500")
        #expect(viewModel.canSave)
        #expect(viewModel.save() == .saved(updatedJob))
        #expect(saveCalls == 2)
    }

    private func makeViewModel(
        locale: Locale = Locale(identifier: "en_US"),
        save: @escaping (WorkType) -> Result<Job, AddWorkTypeSaveFailure> = { _ in .failure(.persistence) }
    ) -> AddWorkTypeViewModel {
        AddWorkTypeViewModel(
            currencyCode: "EUR",
            decimalInputLocale: locale,
            saveWorkType: save,
            makeWorkTypeID: { self.workTypeID },
            makePayRateID: { self.payRateID }
        )
    }

    private func makeValid(_ viewModel: AddWorkTypeViewModel) {
        viewModel.updateNameText("Exams")
        viewModel.selectBasePayBasis(.fixedPerShift)
        viewModel.updateAmountText("500")
    }

    private func makeUpdatedJob() throws -> Job {
        try Job(
            id: UUID(uuid: (0x70, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
            currencyCode: "EUR",
            timeZoneIdentifier: "Europe/Stockholm",
            payCalculationCycle: .perShift,
            workTypes: [
                WorkType(
                    id: workTypeID,
                    name: "Exams",
                    basePayBasis: .fixedPerShift,
                    payRateHistory: try PayRateHistory(payRates: [
                        try PayRate(id: payRateID, amount: 500, effectiveFrom: nil)
                    ])
                )
            ],
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
