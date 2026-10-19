import UIKit

/// Decorative paper only; receipt content remains ordinary, interactive UIKit views.
final class OverviewReceiptPaperView: UIView {
    static let surface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.14, blue: 0.15, alpha: 1)
            : UIColor(red: 0.985, green: 0.975, blue: 0.95, alpha: 1)
    }

    static let selectedSurface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.21, blue: 0.22, alpha: 1)
            : UIColor(red: 0.94, green: 0.925, blue: 0.88, alpha: 1)
    }

    private let paperLayer = CAShapeLayer()
    private var lastSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        layer.insertSublayer(paperLayer, at: 0)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateAppearance()
        }
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        lastSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        paperLayer.frame = bounds
        let path = Self.paperPath(in: paperLayer.bounds)
        paperLayer.path = path.cgPath
        paperLayer.shadowPath = path.cgPath
        paperLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        CATransaction.commit()
    }

    private func updateAppearance() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        paperLayer.fillColor = Self.surface.resolvedColor(with: traitCollection).cgColor
        paperLayer.shadowColor = UIColor.black.cgColor
        paperLayer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0 : 0.10
        paperLayer.shadowRadius = 8
        paperLayer.shadowOffset = CGSize(width: 0, height: 3)
        CATransaction.commit()
    }

    static func paperPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > 0, rect.height > 12 else { return path }
        // Whole semicircular cutouts, with equal straight shoulders at both corners.
        let count = max(1, Int(rect.width / 10))
        let pitch = rect.width / CGFloat(count)
        let radius = min(2.5, pitch / 4)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        for index in 0..<count {
            let centerX = rect.minX + (CGFloat(index) + 0.5) * pitch
            path.addLine(to: CGPoint(x: centerX - radius, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: centerX, y: rect.minY), radius: radius,
                        startAngle: .pi, endAngle: 0, clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        for index in (0..<count).reversed() {
            let centerX = rect.minX + (CGFloat(index) + 0.5) * pitch
            path.addLine(to: CGPoint(x: centerX + radius, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: centerX, y: rect.maxY), radius: radius,
                        startAngle: 0, endAngle: .pi, clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.close()
        return path
    }
}

final class OverviewReceiptRuleView: UIView {
    private let ruleLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        layer.addSublayer(ruleLayer)
        ruleLayer.fillColor = nil
        ruleLayer.lineDashPattern = [1, 3]
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.updateColor()
        }
        updateColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ruleLayer.frame = bounds
        ruleLayer.lineWidth = 1 / (window?.screen.scale ?? UIScreen.main.scale)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        ruleLayer.path = path.cgPath
        CATransaction.commit()
    }

    private func updateColor() {
        ruleLayer.strokeColor = ShiftLedgerColors.textTertiary.resolvedColor(with: traitCollection).cgColor
    }
}
