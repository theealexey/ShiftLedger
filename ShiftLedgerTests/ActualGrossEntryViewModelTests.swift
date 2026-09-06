import Foundation
import Testing
@testable import ShiftLedger

@MainActor
struct ActualGrossEntryViewModelTests {
    private let englishLocale = Locale(identifier: "en_US_POSIX")
    private let commaLocale = Locale(identifier: "sv_SE")

    @Test("Initial amount text is empty")
    func initialAmountTextIsEmpty() {
        #expect(makeViewModel().amountText.isEmpty)
    }

    @Test("Empty input cannot continue")
    func emptyInputCannotContinue() {
        #expect(makeViewModel().canContinue == false)
    }

    @Test("Zero is valid input")
    func zeroIsValid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("0")

        #expect(viewModel.canContinue)
    }

    @Test("Zero produces ActualGross with zero amount")
    func zeroProducesActualGross() throws {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("0")

        let actualGross = try viewModel.makeActualGross().get()

        #expect(actualGross.amount == .zero)
    }

    @Test("Positive integer is valid")
    func positiveIntegerIsValid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("1500")

        #expect(viewModel.canContinue)
    }

    @Test("Positive decimal is valid")
    func positiveDecimalIsValid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("12.34")

        #expect(viewModel.canContinue)
    }

    @Test("Exact Decimal precision is preserved")
    func exactDecimalPrecisionIsPreserved() throws {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("1234.56789")

        let actualGross = try viewModel.makeActualGross().get()
        let expected = try #require(Decimal(string: "1234.56789", locale: englishLocale))

        #expect(actualGross.amount == expected)
    }

    @Test("English locale accepts a period decimal separator")
    func englishLocaleAcceptsPeriod() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("12.34")

        #expect(viewModel.canContinue)
    }

    @Test("Comma locale accepts a comma decimal separator")
    func commaLocaleAcceptsComma() throws {
        let viewModel = makeViewModel(locale: commaLocale)
        viewModel.updateAmountText("12,34")
        let expected = try #require(Decimal(string: "12.34", locale: englishLocale))

        let actualGross = try viewModel.makeActualGross().get()

        #expect(actualGross.amount == expected)
    }

    @Test("Comma locale rejects a period decimal separator")
    func commaLocaleRejectsPeriod() {
        let viewModel = makeViewModel(locale: commaLocale)
        viewModel.updateAmountText("12.34")

        #expect(viewModel.canContinue == false)
    }

    @Test("English locale rejects a comma decimal separator")
    func englishLocaleRejectsComma() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("12,34")

        #expect(viewModel.canContinue == false)
    }

    @Test("Multiple decimal separators are invalid")
    func multipleDecimalSeparatorsAreInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("1.2.3")

        #expect(viewModel.canContinue == false)
    }

    @Test("A separator without a fraction is invalid")
    func trailingSeparatorIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("5.")

        #expect(viewModel.canContinue == false)
    }

    @Test("A separator without an integer is invalid")
    func leadingSeparatorIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText(".5")

        #expect(viewModel.canContinue == false)
    }

    @Test("Alphabetic input is invalid")
    func alphabeticInputIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("12abc")

        #expect(viewModel.canContinue == false)
    }

    @Test("Whitespace and grouping input is invalid")
    func whitespaceGroupedInputIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("1 000")

        #expect(viewModel.canContinue == false)
    }

    @Test("Negative text is invalid")
    func negativeTextIsInvalid() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("-1")

        #expect(viewModel.canContinue == false)
    }

    @Test("Invalid construction returns typed presentation failure")
    func invalidConstructionReturnsTypedFailure() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("invalid")

        #expect(viewModel.makeActualGross() == .failure(.invalidAmount))
    }

    @Test("Valid construction returns the Domain ActualGross")
    func validConstructionReturnsActualGross() throws {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("250.75")
        let amount = try #require(Decimal(string: "250.75", locale: englishLocale))

        let actualGross = try viewModel.makeActualGross().get()

        #expect(actualGross == (try ActualGross(amount: amount)))
    }

    @Test("Changing invalid input to valid updates canContinue")
    func invalidToValidUpdatesCanContinue() {
        let viewModel = makeViewModel()
        viewModel.updateAmountText("12abc")
        #expect(viewModel.canContinue == false)

        viewModel.updateAmountText("12.34")

        #expect(viewModel.canContinue)
    }

    private func makeViewModel(
        locale: Locale? = nil
    ) -> ActualGrossEntryViewModel {
        ActualGrossEntryViewModel(decimalInputLocale: locale ?? englishLocale)
    }
}
