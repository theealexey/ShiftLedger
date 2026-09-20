import Foundation

enum WorkTypeInputParser {
    static func normalizedName(_ text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func decimalAmount(_ text: String, locale: Locale) -> Decimal? {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let components = text.components(separatedBy: decimalSeparator)

        guard
            components.count <= 2,
            components.allSatisfy({
                $0.isEmpty == false && $0.allSatisfy(\.isWholeNumber)
            }),
            let amount = Decimal(string: text, locale: locale)
        else {
            return nil
        }

        return amount
    }
}
