import UIKit

final class FilledTextField: UITextField {
    private let textInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = ShiftLedgerColors.backgroundSecondary
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) {
            (self: FilledTextField, _) in
            self.updateBorderColor()
        }
        addAction(UIAction { [weak self] _ in
            self?.updateBorderColor()
        }, for: [.editingDidBegin, .editingDidEnd])
        updateBorderColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        super.textRect(forBounds: bounds.inset(by: textInsets))
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        super.editingRect(forBounds: bounds.inset(by: textInsets))
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        super.placeholderRect(forBounds: bounds.inset(by: textInsets))
    }

    private func updateBorderColor() {
        layer.borderWidth = isFirstResponder ? 1 : 0
        let color = ShiftLedgerColors.accentPrimary.withAlphaComponent(0.4)
        layer.borderColor = color.resolvedColor(with: traitCollection).cgColor
    }
}
