import UIKit

enum ShiftSurfaceRole: CaseIterable {
    case mint
    case camel
    case yellow
    case coral
    case coolGray
    case orange
}

enum ShiftLedgerColors {
    static let backgroundPrimary = UIColor(resource: .DesignSystem.backgroundPrimary)
    static let backgroundSecondary = UIColor(resource: .DesignSystem.backgroundSecondary)
    static let surfacePrimary = UIColor(resource: .DesignSystem.surfacePrimary)

    static let textPrimary = UIColor(resource: .DesignSystem.textPrimary)
    static let textSecondary = UIColor(resource: .DesignSystem.textSecondary)
    static let textTertiary = UIColor(resource: .DesignSystem.textTertiary)

    static let accentPrimary = UIColor(resource: .DesignSystem.accentPrimary)
    static let textOnAccent = UIColor.black
    static let separator = UIColor(resource: .DesignSystem.separator)

    static let statusPositive = UIColor(resource: .DesignSystem.statusPositive)
    static let statusNegative = UIColor(resource: .DesignSystem.statusNegative)
    static let statusWarning = UIColor(resource: .DesignSystem.statusWarning)

    static func shiftSurfaceRoles(for shiftIDs: [UUID]) -> [ShiftSurfaceRole] {
        var previousRole: ShiftSurfaceRole?
        return shiftIDs.map { id in
            let preferredRole = preferredShiftSurfaceRole(for: id)
            let resolvedRole = preferredRole == previousRole
                ? nextShiftSurfaceRole(after: preferredRole)
                : preferredRole
            previousRole = resolvedRole
            return resolvedRole
        }
    }

    static func shiftSurface(for role: ShiftSurfaceRole) -> UIColor {
        UIColor { traits in
            switch (traits.userInterfaceStyle, role) {
            case (.dark, .mint):
                UIColor(red: 0.32, green: 0.48, blue: 0.44, alpha: 1)
            case (.dark, .camel):
                UIColor(red: 0.50, green: 0.40, blue: 0.28, alpha: 1)
            case (.dark, .yellow):
                UIColor(red: 0.52, green: 0.50, blue: 0.18, alpha: 1)
            case (.dark, .coral):
                UIColor(red: 0.56, green: 0.21, blue: 0.20, alpha: 1)
            case (.dark, .coolGray):
                UIColor(red: 0.38, green: 0.40, blue: 0.43, alpha: 1)
            case (.dark, .orange):
                UIColor(red: 0.59, green: 0.25, blue: 0.12, alpha: 1)
            case (_, .mint):
                UIColor(red: 0.66, green: 0.78, blue: 0.75, alpha: 1)
            case (_, .camel):
                UIColor(red: 0.73, green: 0.60, blue: 0.44, alpha: 1)
            case (_, .yellow):
                UIColor(red: 0.90, green: 0.87, blue: 0.42, alpha: 1)
            case (_, .coral):
                UIColor(red: 0.87, green: 0.29, blue: 0.26, alpha: 1)
            case (_, .coolGray):
                UIColor(red: 0.72, green: 0.74, blue: 0.76, alpha: 1)
            case (_, .orange):
                UIColor(red: 0.91, green: 0.48, blue: 0.18, alpha: 1)
            }
        }
    }

    static func shiftForeground(for role: ShiftSurfaceRole) -> UIColor {
        UIColor { traits in
            switch (traits.userInterfaceStyle, role) {
            case (.dark, _):
                .white
            case (_, .mint), (_, .camel), (_, .yellow), (_, .coral), (_, .coolGray), (_, .orange):
                UIColor(white: 0.10, alpha: 1)
            }
        }
    }

    static func stableSurfaceIndex(for id: UUID) -> Int {
        id.uuidString.utf8.reduce(0) { partialResult, byte in
            (partialResult &* 31 &+ Int(byte)) % ShiftSurfaceRole.allCases.count
        }
    }

    private static func preferredShiftSurfaceRole(for id: UUID) -> ShiftSurfaceRole {
        switch stableSurfaceIndex(for: id) {
        case 0:
            .mint
        case 1:
            .camel
        case 2:
            .yellow
        case 3:
            .coral
        case 4:
            .coolGray
        default:
            .orange
        }
    }

    private static func nextShiftSurfaceRole(after role: ShiftSurfaceRole) -> ShiftSurfaceRole {
        switch role {
        case .mint:
            .camel
        case .camel:
            .yellow
        case .yellow:
            .coral
        case .coral:
            .coolGray
        case .coolGray:
            .orange
        case .orange:
            .mint
        }
    }
}
