import Foundation

@MainActor
final class ActualGrossEntryViewModel {
    enum Failure: Error, Equatable {
        case invalidAmount
    }

    private(set) var amountText = ""
    private let decimalInputLocale: Locale

    init(decimalInputLocale: Locale = .current) {
        self.decimalInputLocale = decimalInputLocale
    }

    var canContinue: Bool {
        switch makeActualGross() {
        case .success:
            true
        case .failure:
            false
        }
    }

    func updateAmountText(_ text: String) {
        amountText = text
    }

    func makeActualGross() -> Result<ActualGross, Failure> {
        guard let amount = parseAmount() else {
            return .failure(.invalidAmount)
        }

        do {
            return .success(try ActualGross(amount: amount))
        } catch {
            return .failure(.invalidAmount)
        }
    }

    private func parseAmount() -> Decimal? {
        let decimalSeparator = decimalInputLocale.decimalSeparator ?? "."
        let components = amountText.components(separatedBy: decimalSeparator)

        guard
            components.count <= 2,
            components.allSatisfy({
                $0.isEmpty == false && $0.allSatisfy(\.isWholeNumber)
            })
        else {
            return nil
        }

        return Decimal(string: amountText, locale: decimalInputLocale)
    }
}
