import Foundation

enum PayRateDecimalCodec {
    enum Failure: Error, Equatable {
        case nonFiniteOrNonPositive
        case nonCanonical
    }

    private static let locale = Locale(identifier: "en_US_POSIX")

    static func encode(_ amount: Decimal) throws(Failure) -> String {
        guard !amount.isNaN, amount > .zero else { throw .nonFiniteOrNonPositive }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    static func decode(_ text: String) throws(Failure) -> Decimal {
        guard let amount = Decimal(string: text, locale: locale),
              try encode(amount) == text else { throw .nonCanonical }
        return amount
    }
}
