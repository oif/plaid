//
//  CardStyles.swift
//  Plaid
//
//  Reusable card wrapper components with consistent styling and hover interactions.
//

import SwiftUI

// MARK: - Card Style Protocol

/// Protocol defining card appearance customization.
/// Conformers provide a custom body wrapper for card content.
protocol PlaidCardStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(content: Content) -> Body
    typealias Content = AnyView
}

// MARK: - Standard Card

/// Basic card wrapper with subtle background and hover effect.
/// Usage: `StandardCard { YourContent() }`
struct StandardCard<Content: View>: View {
    @State private var isHovered = false
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(PlaidSpacing.lg)
            .background(PlaidColors.Background.secondary, in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PlaidRadius.lg)
                    .strokeBorder(.secondary.opacity(isHovered ? PlaidOpacity.medium : PlaidOpacity.subtle), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Hero Card

/// Featured card with gradient background and glow effect.
/// Usage: `HeroCard { YourContent().foregroundStyle(.white) }`
struct HeroCard<Content: View>: View {
    @State private var isHovered = false
    let gradient: LinearGradient
    let content: Content
    
    init(
        gradient: LinearGradient = LinearGradient(
            colors: [
                Color(hue: 0.38, saturation: 0.65, brightness: 0.55),
                Color(hue: 0.45, saturation: 0.70, brightness: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(PlaidSpacing.xl)
            .background {
                ZStack {
                    gradient
                    
                    // Glow effect - adds depth and visual interest
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(PlaidOpacity.medium), .clear],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .offset(x: 60, y: -40)
                    
                    RoundedRectangle(cornerRadius: PlaidRadius.xl)
                        .strokeBorder(.white.opacity(PlaidOpacity.light), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PlaidRadius.xl))
            .shadow(
                color: Color(hue: 0.40, saturation: 0.50, brightness: 0.30).opacity(isHovered ? 0.4 : PlaidOpacity.prominent),
                radius: isHovered ? 20 : 12,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Interactive Card

/// Card with accent-colored hover border, ideal for clickable items.
/// Usage: `InteractiveCard(accentColor: .purple) { YourContent() }`
struct InteractiveCard<Content: View>: View {
    @State private var isHovered = false
    let accentColor: Color
    let content: Content
    
    init(accentColor: Color = .accentColor, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(PlaidSpacing.lg)
            .background(PlaidColors.Background.secondary, in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: PlaidRadius.lg)
                    .strokeBorder(accentColor.opacity(isHovered ? 0.25 : 0), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Preview

#Preview("Card Styles") {
    VStack(spacing: PlaidSpacing.xl) {
        StandardCard {
            VStack(alignment: .leading, spacing: PlaidSpacing.sm) {
                Text("Standard Card")
                    .font(PlaidTypography.sectionTitle)
                Text("Subtle background with light hover effect")
                    .font(PlaidTypography.bodySecondary)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        HeroCard {
            VStack(alignment: .leading, spacing: PlaidSpacing.sm) {
                Text("Hero Card")
                    .font(PlaidTypography.sectionTitle)
                    .foregroundStyle(.white)
                Text("Featured content with gradient and glow")
                    .font(PlaidTypography.bodySecondary)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        InteractiveCard(accentColor: PlaidColors.Accent.ai) {
            VStack(alignment: .leading, spacing: PlaidSpacing.sm) {
                Text("Interactive Card")
                    .font(PlaidTypography.sectionTitle)
                Text("Accent border appears on hover")
                    .font(PlaidTypography.bodySecondary)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(PlaidSpacing.xxl)
    .frame(width: 400)
}
