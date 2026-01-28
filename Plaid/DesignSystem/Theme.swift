//
//  Theme.swift
//  Plaid
//
//  Design system foundation - semantic tokens for colors, spacing, typography, and effects.
//

import SwiftUI

// MARK: - PlaidColors

/// Semantic color tokens organized by purpose.
/// Usage: `PlaidColors.Background.primary`, `PlaidColors.Accent.recording`
enum PlaidColors {
    
    enum Background {
        static let primary = Color(nsColor: .windowBackgroundColor)
        static let secondary = Color.secondary.opacity(PlaidOpacity.subtle)
        static let elevated = Color.secondary.opacity(PlaidOpacity.light)
    }
    
    enum Text {
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let tertiary = Color(nsColor: .tertiaryLabelColor)
    }
    
    enum Accent {
        static let recording = Color.red
        static let voice = Color.orange
        static let ai = Color.purple
        static let stats = Color.blue
        static let success = Color.green
    }
}

// MARK: - PlaidSpacing

/// Spacing scale based on 4pt grid system.
/// Usage: `.padding(PlaidSpacing.md)`, `VStack(spacing: PlaidSpacing.sm)`
enum PlaidSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

// MARK: - PlaidRadius

/// Corner radius tokens for consistent rounded corners.
/// Usage: `RoundedRectangle(cornerRadius: PlaidRadius.md)`
enum PlaidRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 14
    static let xl: CGFloat = 16
}

// MARK: - PlaidOpacity

/// Standardized opacity values replacing hardcoded `.opacity(0.06)` etc.
/// Usage: `.opacity(PlaidOpacity.subtle)`, `Color.secondary.opacity(PlaidOpacity.light)`
enum PlaidOpacity {
    static let invisible: Double = 0
    static let subtle: Double = 0.06       // Background fills, subtle tints
    static let light: Double = 0.1         // Light overlays, secondary backgrounds
    static let medium: Double = 0.15       // Accent backgrounds, hover states
    static let prominent: Double = 0.3     // Visible but not dominant
    static let half: Double = 0.5          // Equal blend
    static let heavy: Double = 0.8         // Near-opaque overlays
}

// MARK: - PlaidTypography

/// Font style tokens for consistent typography.
/// Usage: `.font(PlaidTypography.heroNumber)`, `.font(PlaidTypography.caption)`
enum PlaidTypography {
    static let heroNumber = Font.system(size: 64, weight: .bold, design: .rounded)
    static let cardValue = Font.system(size: 24, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let bodyPrimary = Font.system(size: 15, weight: .medium)
    static let bodySecondary = Font.system(size: 13)
    static let caption = Font.system(size: 11)
    static let badge = Font.system(size: 10, weight: .semibold)
    static let tiny = Font.system(size: 9)
}
