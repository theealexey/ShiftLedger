import UIKit

enum ShiftSurfaceRole: CaseIterable {
    case ivoryBuff
    case pistachioGreen
    case salviaBlue
    case seashellPink
    case glaucousGreen
    case cinnamonBuff
}

enum ShiftLedgerColors {
    static let backgroundPrimary = UIColor(resource: .DesignSystem.backgroundPrimary)
    static let backgroundSecondary = UIColor(resource: .DesignSystem.backgroundSecondary)
    static let surfacePrimary = UIColor(resource: .DesignSystem.surfacePrimary)

    static let textPrimary = UIColor(resource: .DesignSystem.textPrimary)
    static let textSecondary = UIColor(resource: .DesignSystem.textSecondary)
    static let textTertiary = UIColor(resource: .DesignSystem.textTertiary)

    static let accentPrimary = UIColor(resource: .DesignSystem.accentPrimary)
    static let separator = UIColor(resource: .DesignSystem.separator)

    static let statusNegative = UIColor(resource: .DesignSystem.statusNegative)

    static func shiftSurfaceRoles(for shiftIDs: [UUID]) -> [ShiftSurfaceRole] {
        var previousRole: ShiftSurfaceRole?
        let rolesFromOldestToNewest = shiftIDs.reversed().map { id in
            let preferredRole = preferredShiftSurfaceRole(for: id)
            let resolvedRole = preferredRole == previousRole
                ? nextShiftSurfaceRole(after: preferredRole)
                : preferredRole
            previousRole = resolvedRole
            return resolvedRole
        }
        return Array(rolesFromOldestToNewest.reversed())
    }

    static func shiftSurface(for role: ShiftSurfaceRole) -> UIColor {
        switch role {
        case .ivoryBuff:
            UIColor(red: CGFloat(235) / 255.0, green: CGFloat(211) / 255.0, blue: CGFloat(162) / 255.0, alpha: 1)
        case .pistachioGreen:
            UIColor(red: CGFloat(100) / 255.0, green: CGFloat(143) / 255.0, blue: CGFloat(123) / 255.0, alpha: 1)
        case .salviaBlue:
            UIColor(red: CGFloat(151) / 255.0, green: CGFloat(172) / 255.0, blue: CGFloat(200) / 255.0, alpha: 1)
        case .seashellPink:
            UIColor(red: CGFloat(253) / 255.0, green: CGFloat(212) / 255.0, blue: CGFloat(189) / 255.0, alpha: 1)
        case .glaucousGreen:
            UIColor(red: CGFloat(180) / 255.0, green: CGFloat(205) / 255.0, blue: CGFloat(194) / 255.0, alpha: 1)
        case .cinnamonBuff:
            UIColor(red: CGFloat(253) / 255.0, green: CGFloat(197) / 255.0, blue: CGFloat(126) / 255.0, alpha: 1)
        }
    }

    static func shiftForeground(for _: ShiftSurfaceRole) -> UIColor {
        UIColor(red: CGFloat(16) / 255.0, green: CGFloat(19) / 255.0, blue: CGFloat(21) / 255.0, alpha: 1)
    }

    static func stableSurfaceIndex(for id: UUID) -> Int {
        id.uuidString.utf8.reduce(0) { partialResult, byte in
            (partialResult &* 31 &+ Int(byte)) % ShiftSurfaceRole.allCases.count
        }
    }

    private static func preferredShiftSurfaceRole(for id: UUID) -> ShiftSurfaceRole {
        switch stableSurfaceIndex(for: id) {
        case 0:
            .ivoryBuff
        case 1:
            .pistachioGreen
        case 2:
            .salviaBlue
        case 3:
            .seashellPink
        case 4:
            .glaucousGreen
        default:
            .cinnamonBuff
        }
    }

    private static func nextShiftSurfaceRole(after role: ShiftSurfaceRole) -> ShiftSurfaceRole {
        switch role {
        case .ivoryBuff:
            .pistachioGreen
        case .pistachioGreen:
            .salviaBlue
        case .salviaBlue:
            .seashellPink
        case .seashellPink:
            .glaucousGreen
        case .glaucousGreen:
            .cinnamonBuff
        case .cinnamonBuff:
            .ivoryBuff
        }
    }
}
