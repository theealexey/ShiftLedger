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
        // Independent local sequences: width controls the contour, never content height or time.
        let top = tearContour(width: rect.width, seed: 0x5217)
        let bottom = tearContour(width: rect.width, seed: 0xA39B)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 4))
        for point in top {
            path.addLine(to: CGPoint(x: rect.minX + point.x, y: rect.minY + point.y))
        }
        for point in bottom.reversed() {
            path.addLine(to: CGPoint(x: rect.minX + point.x, y: rect.maxY - point.y))
        }
        path.close()
        return path
    }

    private static func tearContour(width: CGFloat, seed: UInt64) -> [CGPoint] {
        var state = seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 32
        }
        var points = [CGPoint(x: 0, y: 4)]
        var x: CGFloat = 0
        while x < width {
            let interval = CGFloat(5 + next() % 8)
            let shallow = next() % 7 == 0
            let depth = shallow ? CGFloat(1) : CGFloat(2 + next() % 5)
            let shoulder = CGFloat(2 + next() % 4) / 10
            let previousDepth = points.last?.y ?? 4
            // Occasionally retain the previous level, producing a short almost-flat tear.
            points.append(CGPoint(x: min(width, x + interval * shoulder),
                                  y: shallow ? previousDepth : depth))
            x = min(width, x + interval)
            points.append(CGPoint(x: x, y: CGFloat(1 + next() % 3)))
        }
        return points
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
