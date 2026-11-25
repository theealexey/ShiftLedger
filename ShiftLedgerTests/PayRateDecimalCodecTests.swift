import Foundation
import Testing
@testable import ShiftLedger

struct PayRateDecimalCodecTests {
    static let samples = [
        "100", "1.004", "1.00412345678901234567890123456789", "0.000000000000000000000001",
        "0." + String(repeating: "0", count: 123) + "12345",
        NSDecimalNumber(decimal: .leastNonzeroMagnitude).stringValue,
        NSDecimalNumber(decimal: .greatestFiniteMagnitude).stringValue
    ]

    @Test(arguments: samples)
    func preservesCanonicalAmount(_ text: String) throws {
        let expected = try #require(Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")))
        #expect(try PayRateDecimalCodec.decode(text) == expected)
        #expect(try PayRateDecimalCodec.encode(expected) == text)
    }

    @Test(arguments: ["", " ", "1junk", "1,004", "NaN", "0", "-1", "1e999", "+1", "01", "1.0",
                      String(repeating: "9", count: 180), "1.1234567890123456789012345678901234567890123456789"])
    func rejectsInvalidStoredAmount(_ text: String) {
        #expect(throws: PayRateDecimalCodec.Failure.self) { try PayRateDecimalCodec.decode(text) }
    }

    @Test
    func rejectsNonPositiveAndNaNInputs() {
        for amount in [Decimal.zero, -Decimal(1), .nan] {
            #expect(throws: PayRateDecimalCodec.Failure.nonFiniteOrNonPositive) {
                try PayRateDecimalCodec.encode(amount)
            }
        }
    }
}
