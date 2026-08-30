import UIKit

enum ShiftLedgerTypography {
    static var display: UIFont {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font)
    }

    static var basePayAmount: UIFont {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        return UIFontMetrics(forTextStyle: .title1).scaledFont(for: font)
    }

    static var basePayCurrency: UIFont {
        let font = UIFont.systemFont(ofSize: 26, weight: .regular)
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: font)
    }

    static var largeTitle: UIFont {
        UIFont.preferredFont(forTextStyle: .largeTitle)
    }

    static var onboardingQuestion: UIFont {
        let font = UIFont.systemFont(ofSize: 30, weight: .semibold)
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font)
    }

    static var title: UIFont {
        UIFont.preferredFont(forTextStyle: .title1)
    }

    static var setupInput: UIFont {
        let font = UIFont.systemFont(ofSize: 25, weight: .regular)
        return UIFontMetrics(forTextStyle: .title2).scaledFont(for: font)
    }

    static var headline: UIFont {
        UIFont.preferredFont(forTextStyle: .headline)
    }

    static var body: UIFont {
        UIFont.preferredFont(forTextStyle: .body)
    }

    static var callout: UIFont {
        UIFont.preferredFont(forTextStyle: .callout)
    }

    static var caption: UIFont {
        UIFont.preferredFont(forTextStyle: .caption1)
    }

    static var button: UIFont {
        UIFont.preferredFont(forTextStyle: .headline)
    }
}
