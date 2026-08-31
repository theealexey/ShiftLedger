import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct AddShiftViewModelTests {
    private let start = Date(timeIntervalSince1970: 1_788_076_800)
    private let end = Date(timeIntervalSince1970: 1_788_105_600)

    @Test("Неполный draft нельзя сохранить")
    func initialStateCannotSave() {
        let viewModel = makeViewModel()
        #expect(viewModel.start == nil)
        #expect(viewModel.end == nil)
        #expect(viewModel.canSave == false)
        #expect(viewModel.save() == .invalid)
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
        let expectedShift = try Shift(id: knownID, start: start, end: end)
        #expect(viewModel.save() == .saved(expectedShift))
        #expect(calls == 1)
    }

    @Test("Повторный Save во время синхронной операции игнорируется")
    func reentrantSaveIsIgnored() {
        var viewModel: AddShiftViewModel?
        var saveCalls = 0
        let result = Result<Void, AddShiftSaveFailure>.success(())
        viewModel = AddShiftViewModel(timeZoneIdentifier: "Europe/Stockholm", saveShift: { _ in
            saveCalls += 1
            #expect(viewModel?.save() == .ignored)
            return result
        }, makeID: { knownID })
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

    private var knownID: UUID {
        UUID(uuidString: "50000000-0000-0000-0000-000000000001") ?? UUID()
    }

    private func makeViewModel(
        saveShift: @escaping (Shift) -> Result<Void, AddShiftSaveFailure> = { _ in .success(()) },
        makeID: @escaping () -> UUID = { UUID(uuidString: "50000000-0000-0000-0000-000000000001") ?? UUID() }
    ) -> AddShiftViewModel {
        AddShiftViewModel(timeZoneIdentifier: "Europe/Stockholm", saveShift: saveShift, makeID: makeID)
    }
}

private extension AddShiftSaveResult {
    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }
}
