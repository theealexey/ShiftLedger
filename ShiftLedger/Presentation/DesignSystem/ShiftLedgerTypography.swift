import UIKit

enum ShiftLedgerTypography {
    static var display: UIFont {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font)
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
