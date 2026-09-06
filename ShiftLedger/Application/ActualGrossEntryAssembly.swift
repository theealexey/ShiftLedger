import Foundation

@MainActor
enum ActualGrossEntryAssembly {
    static func make(
        currencyCode: String,
        decimalInputLocale: Locale = .current
    ) -> ActualGrossEntryViewController {
        let viewModel = ActualGrossEntryViewModel(decimalInputLocale: decimalInputLocale)
        return ActualGrossEntryViewController(
            viewModel: viewModel,
            currencyCode: currencyCode
        )
    }
}
