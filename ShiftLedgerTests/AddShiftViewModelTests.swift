import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct AddShiftViewModelTests {
    private let start = Date(timeIntervalSince1970: 1_788_076_800)
    private let end = Date(timeIntervalSince1970: 1_788_105_600)
    private let soleWorkType: WorkType

    init() throws {
        soleWorkType = WorkType(
            id: testWorkTypeID,
            name: "Lectures",
            basePayBasis: .hourly,
            payRateHistory: try PayRateHistory(
                payRates: [
                    try PayRate(
                        id: UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                        amount: 100,
                        effectiveFrom: nil
                    )
                ]
            )
        )
    }

    @Test("Неполный draft нельзя сохранить")
    func initialStateCannotSave() {
        let viewModel = makeViewModel()
        #expect(viewModel.start == nil)
        #expect(viewModel.end == nil)
        #expect(viewModel.canSave == false)
        #expect(viewModel.save() == .invalid)
    }

    @Test("Сброс возвращает draft к начальному состоянию")
    func resetRestoresInitialState() {
        let timeZoneIdentifier = "Europe/Stockholm"
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: timeZoneIdentifier,
            workTypes: [soleWorkType],
            saveShift: { _ in .success(()) }
        )
        viewModel.setStart(start)
        viewModel.setEnd(end)
        viewModel.setUnpaidBreakEnabled(true)
        viewModel.setBreakStart(start.addingTimeInterval(60))
        viewModel.setBreakEnd(start.addingTimeInterval(120))

        viewModel.reset()

        #expect(viewModel.start == nil)
        #expect(viewModel.end == nil)
        #expect(viewModel.isUnpaidBreakEnabled == false)
        #expect(viewModel.breakStart == nil)
        #expect(viewModel.breakEnd == nil)
        #expect(viewModel.canSave == false)
        #expect(viewModel.validationError == nil)
        #expect(viewModel.timeZoneIdentifier == timeZoneIdentifier)
    }

    @Test("Start без End нельзя сохранить")
    func startOnlyCannotSave() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        #expect(viewModel.canSave == false)
    }

    @Test("Неполный draft возвращает typed ошибку")
    func makeShiftRejectsIncompleteDraft() {
        let viewModel = makeViewModel()

        #expect(throws: AddShiftValidationError.incomplete) {
            try viewModel.makeShift(id: knownID)
        }
    }

    @Test("Некорректные даты возвращают Domain ошибку")
    func makeShiftWrapsDomainValidationError() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(start)

        #expect(throws: AddShiftValidationError.invalidShift(.startNotBeforeEnd)) {
            try viewModel.makeShift(id: knownID)
        }
    }

    @Test("Валидный same-day Shift сохраняет абсолютные даты")
    func validShiftPreservesDates() throws {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)
        #expect(viewModel.canSave)
        let shift = try viewModel.makeShift(id: knownID)
        #expect(shift.workTypeID == testWorkTypeID)
        #expect(shift.start == start)
        #expect(shift.end == end)
    }

    @Test("Одинаковые и перевёрнутые даты отклоняются")
    func invalidOrderCannotSave() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(start)
        #expect(viewModel.canSave == false)
        #expect(viewModel.validationError == .startNotBeforeEnd)
        viewModel.setEnd(start.addingTimeInterval(-1))
        #expect(viewModel.validationError == .startNotBeforeEnd)
    }

    @Test("Ограничение 48 часов используется из Domain")
    func durationValidation() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(start.addingTimeInterval(48 * 60 * 60))
        #expect(viewModel.canSave)
        viewModel.setEnd(start.addingTimeInterval(48 * 60 * 60 + 1))
        #expect(viewModel.canSave == false)
        #expect(viewModel.validationError == .durationExceedsLimit)
    }

    @Test("Ночная смена остаётся абсолютным интервалом")
    func overnightShiftCanSave() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(start.addingTimeInterval(12 * 60 * 60))
        #expect(viewModel.canSave)
    }

    @Test("Перерыв выключен и не попадает в Domain Shift")
    func disabledBreakIsNil() throws {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)
        viewModel.setBreakStart(start.addingTimeInterval(60))
        viewModel.setBreakEnd(start.addingTimeInterval(120))
        let shift = try viewModel.makeShift(id: knownID)
        #expect(shift.unpaidBreak == nil)
    }

    @Test("Включённый перерыв требует обе даты и сохраняет их точно")
    func enabledBreakRequiresDates() throws {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)
        viewModel.setUnpaidBreakEnabled(true)
        #expect(viewModel.canSave == false)
        let breakStart = start.addingTimeInterval(4 * 60 * 60)
        let breakEnd = start.addingTimeInterval(4.5 * 60 * 60)
        viewModel.setBreakStart(breakStart)
        #expect(viewModel.canSave == false)
        viewModel.setBreakEnd(breakEnd)
        #expect(viewModel.canSave)
        #expect(try viewModel.makeShift(id: knownID).unpaidBreak == UnpaidBreak(start: breakStart, end: breakEnd))
    }

    @Test("Некорректные перерывы показывают Domain validation")
    func invalidBreaksCannotSave() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)
        viewModel.setUnpaidBreakEnabled(true)
        viewModel.setBreakStart(start.addingTimeInterval(-1))
        viewModel.setBreakEnd(start.addingTimeInterval(60))
        #expect(viewModel.validationError == .breakOutsideShift)
        viewModel.setBreakStart(end)
        viewModel.setBreakEnd(end)
        #expect(viewModel.validationError == .breakStartNotBeforeEnd)
        viewModel.setBreakStart(end.addingTimeInterval(-60))
        viewModel.setBreakEnd(end.addingTimeInterval(60))
        #expect(viewModel.validationError == .breakOutsideShift)
        viewModel.setBreakStart(start)
        viewModel.setBreakEnd(end)
        #expect(viewModel.validationError == .breakConsumesEntireShift)
    }

    @Test("Выключение и повторное включение сохраняет presentation dates")
    func togglingBreakPreservesDraftButControlsDomainValue() throws {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)
        let breakStart = start.addingTimeInterval(60)
        let breakEnd = start.addingTimeInterval(120)
        viewModel.setBreakStart(breakStart)
        viewModel.setBreakEnd(breakEnd)
        viewModel.setUnpaidBreakEnabled(true)
        viewModel.setUnpaidBreakEnabled(false)
        #expect(try viewModel.makeShift(id: knownID).unpaidBreak == nil)
        viewModel.setUnpaidBreakEnabled(true)
        #expect(try viewModel.makeShift(id: knownID).unpaidBreak == UnpaidBreak(start: breakStart, end: breakEnd))
    }

    @Test("UUID generator используется один раз при успешном сохранении")
    func idGeneratorUsedOnce() throws {
        var calls = 0
        let viewModel = makeViewModel(makeID: {
            calls += 1
            return knownID
        })
        viewModel.setStart(start)
        viewModel.setEnd(end)
        let expectedShift = try Shift(
            id: knownID,
            workTypeID: testWorkTypeID,
            start: start,
            end: end
        )
        #expect(viewModel.save() == .saved(expectedShift))
        #expect(calls == 1)
    }

    @Test("Повторный Save во время синхронной операции игнорируется")
    func reentrantSaveIsIgnored() {
        var viewModel: AddShiftViewModel?
        var saveCalls = 0
        let result = Result<Void, AddShiftSaveFailure>.success(())
        viewModel = AddShiftViewModel(
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [soleWorkType],
            saveShift: { _ in
            saveCalls += 1
            #expect(viewModel?.save() == .ignored)
            return result
            },
            makeID: { knownID }
        )
        guard let viewModel else { return }
        viewModel.setStart(start)
        viewModel.setEnd(end)
        _ = viewModel.save()
        #expect(saveCalls == 1)
    }

    @Test("Overlap и generic failure позволяют повторить попытку")
    func saveFailuresMapAndRetry() {
        var outcome: Result<Void, AddShiftSaveFailure> = .failure(.overlap)
        var calls = 0
        let viewModel = makeViewModel(saveShift: { _ in
            calls += 1
            return outcome
        })
        viewModel.setStart(start)
        viewModel.setEnd(end)
        #expect(viewModel.save() == .failed(.overlap))
        outcome = .failure(.generic)
        #expect(viewModel.save() == .failed(.generic))
        outcome = .success(())
        #expect(viewModel.save().isSaved)
        #expect(calls == 3)
    }

    @Test("Стокгольм и форматирование используют timezone Job")
    func timezoneFormattingIsDeterministic() throws {
        let instant = Date(timeIntervalSince1970: 1_788_048_000)
        let stockholm = try #require(AddShiftDateFormatting.string(for: instant, timeZoneIdentifier: "Europe/Stockholm", locale: Locale(identifier: "en_US")))
        let utc = try #require(AddShiftDateFormatting.string(for: instant, timeZoneIdentifier: "UTC", locale: Locale(identifier: "en_US")))
        #expect(stockholm != utc)
    }

    @Test("Региональная локаль управляет 12- и 24-часовым временем")
    func regionalLocaleControlsTimeConvention() throws {
        let instant = Date(timeIntervalSince1970: 1_788_094_800)
        let us = try #require(
            AddShiftDateFormatting.string(
                for: instant,
                timeZoneIdentifier: "Europe/Stockholm",
                locale: Locale(identifier: "en_US")
            )
        )
        let gb = try #require(
            AddShiftDateFormatting.string(
                for: instant,
                timeZoneIdentifier: "Europe/Stockholm",
                locale: Locale(identifier: "en_GB")
            )
        )

        #expect(us.contains("PM"))
        #expect(gb.contains("15:00"))
    }

    @Test("Форматирование не меняет абсолютный Date")
    func formattingDoesNotMutateDate() throws {
        let instant = Date(timeIntervalSince1970: 1_788_048_000)
        _ = AddShiftDateFormatting.string(for: instant, timeZoneIdentifier: "Europe/Stockholm", locale: Locale(identifier: "en_US"))
        #expect(instant == Date(timeIntervalSince1970: 1_788_048_000))
    }

    @Test("Отсутствующее назначение WorkType блокирует сохранение")
    func missingWorkTypeAssignmentIsRejected() {
        let viewModel = AddShiftViewModel(
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: [],
            initialStart: start,
            initialEnd: end,
            saveShift: { _ in .success(()) }
        )

        #expect(viewModel.canSave == false)
        #expect(throws: AddShiftValidationError.missingWorkTypeAssignment) {
            try viewModel.makeShift(id: knownID)
        }
        #expect(viewModel.save() == .invalid)
    }

    @Test("Единственный WorkType выбирается автоматически")
    func soleWorkTypeIsAutomaticallySelected() {
        let viewModel = makeViewModel()

        #expect(viewModel.selectedWorkTypeID == soleWorkType.id)
        #expect(viewModel.selectedWorkType == AddShiftWorkTypeOption(id: soleWorkType.id, name: "Lectures"))
    }

    @Test("Единственный WorkType позволяет сохранить валидные даты")
    func soleWorkTypeAllowsValidShift() {
        let viewModel = makeViewModel()
        viewModel.setStart(start)
        viewModel.setEnd(end)

        #expect(viewModel.canSave)
    }

    @Test("Несколько WorkTypes требуют явного выбора")
    func multipleWorkTypesRequireSelection() throws {
        let workTypes = try makeMultipleWorkTypes()
        let viewModel = makeViewModel(workTypes: workTypes)
        viewModel.setStart(start)
        viewModel.setEnd(end)

        #expect(viewModel.selectedWorkTypeID == nil)
        #expect(viewModel.canSave == false)
        #expect(throws: AddShiftValidationError.missingWorkTypeAssignment) {
            try viewModel.makeShift(id: knownID)
        }
    }

    @Test("Выбор принимает точный известный ID и отклоняет неизвестный")
    func selectionAcceptsKnownIDAndRejectsUnknownID() throws {
        let workTypes = try makeMultipleWorkTypes()
        let viewModel = makeViewModel(workTypes: workTypes)
        let expectedID = workTypes[1].id
        let unknownID = UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))

        #expect(viewModel.selectWorkType(id: expectedID))
        #expect(viewModel.selectedWorkTypeID == expectedID)
        #expect(viewModel.selectWorkType(id: unknownID) == false)
        #expect(viewModel.selectedWorkTypeID == expectedID)
    }

    @Test("Shift получает ID каждого явно выбранного WorkType")
    func makeShiftUsesExactSelectedWorkTypeID() throws {
        let workTypes = try makeMultipleWorkTypes()
        let viewModel = makeViewModel(workTypes: workTypes)
        viewModel.setStart(start)
        viewModel.setEnd(end)

        for workType in workTypes {
            #expect(viewModel.selectWorkType(id: workType.id))
            #expect(try viewModel.makeShift(id: knownID).workTypeID == workType.id)
        }
    }

    @Test("Reset восстанавливает sole selection и очищает multi selection")
    func resetRestoresInitialSelectionSemantics() throws {
        let soleViewModel = makeViewModel()
        soleViewModel.reset()
        #expect(soleViewModel.selectedWorkTypeID == soleWorkType.id)

        let workTypes = try makeMultipleWorkTypes()
        let multiViewModel = makeViewModel(workTypes: workTypes)
        #expect(multiViewModel.selectWorkType(id: workTypes[1].id))
        multiViewModel.reset()
        #expect(multiViewModel.selectedWorkTypeID == nil)
    }

    @Test("Presentation options сохраняют ID, имена, nil и входной порядок")
    func presentationOptionsPreserveInputValuesAndOrder() throws {
        let workTypes = try makeMultipleWorkTypes()
        let viewModel = makeViewModel(workTypes: workTypes)

        #expect(viewModel.workTypeOptions == [
            AddShiftWorkTypeOption(id: workTypes[0].id, name: workTypes[0].name),
            AddShiftWorkTypeOption(id: workTypes[1].id, name: workTypes[1].name)
        ])
        #expect(viewModel.workTypeOptions[1].name == nil)
    }

    private var knownID: UUID {
        UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }

    private func makeViewModel(
        workTypes: [WorkType]? = nil,
        saveShift: @escaping (Shift) -> Result<Void, AddShiftSaveFailure> = { _ in .success(()) },
        makeID: @escaping () -> UUID = {
            UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        }
    ) -> AddShiftViewModel {
        AddShiftViewModel(
            timeZoneIdentifier: "Europe/Stockholm",
            workTypes: workTypes ?? [soleWorkType],
            saveShift: saveShift,
            makeID: makeID
        )
    }

    private func makeMultipleWorkTypes() throws -> [WorkType] {
        [
            WorkType(
                id: UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
                name: "Lectures",
                basePayBasis: .hourly,
                payRateHistory: try PayRateHistory(
                    payRates: [
                        try PayRate(
                            id: UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4)),
                            amount: 100,
                            effectiveFrom: nil
                        )
                    ]
                )
            ),
            WorkType(
                id: UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)),
                name: nil,
                basePayBasis: .fixedPerShift,
                payRateHistory: try PayRateHistory(
                    payRates: [
                        try PayRate(
                            id: UUID(uuid: (0x50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6)),
                            amount: 500,
                            effectiveFrom: nil
                        )
                    ]
                )
            )
        ]
    }
}

private extension AddShiftSaveResult {
    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }
}
