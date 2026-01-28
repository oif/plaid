//
//  ButtonStyles.swift
//  Plaid
//
//  Unified button style variants using design system tokens.
//

import SwiftUI

// MARK: - Plaid Button Style (Base)

struct PlaidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PlaidSpacing.md)
            .padding(.vertical, PlaidSpacing.sm)
            .background(
                configuration.isPressed
                    ? Color.secondary.opacity(PlaidOpacity.light)
                    : Color.secondary.opacity(PlaidOpacity.subtle),
                in: RoundedRectangle(cornerRadius: PlaidRadius.sm)
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Primary Button Style

struct PlaidPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PlaidSpacing.lg)
            .padding(.vertical, PlaidSpacing.md)
            .background(.tint, in: RoundedRectangle(cornerRadius: PlaidRadius.sm))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct PlaidSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PlaidSpacing.md)
            .padding(.vertical, PlaidSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: PlaidRadius.sm)
                    .strokeBorder(.secondary.opacity(PlaidOpacity.prominent), lineWidth: 1)
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

struct PlaidDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, PlaidSpacing.md)
            .padding(.vertical, PlaidSpacing.sm)
            .background(
                configuration.isPressed
                    ? Color.red.opacity(PlaidOpacity.medium)
                    : Color.red.opacity(PlaidOpacity.light),
                in: RoundedRectangle(cornerRadius: PlaidRadius.sm)
            )
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct PlaidIconButtonStyle: ButtonStyle {
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                configuration.isPressed
                    ? Color.secondary.opacity(PlaidOpacity.light)
                    : Color.secondary.opacity(PlaidOpacity.subtle),
                in: Circle()
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PlaidButtonStyle {
    static var plaid: PlaidButtonStyle { PlaidButtonStyle() }
}

extension ButtonStyle where Self == PlaidPrimaryButtonStyle {
    static var plaidPrimary: PlaidPrimaryButtonStyle { PlaidPrimaryButtonStyle() }
}

extension ButtonStyle where Self == PlaidSecondaryButtonStyle {
    static var plaidSecondary: PlaidSecondaryButtonStyle { PlaidSecondaryButtonStyle() }
}

extension ButtonStyle where Self == PlaidDestructiveButtonStyle {
    static var plaidDestructive: PlaidDestructiveButtonStyle { PlaidDestructiveButtonStyle() }
}

extension ButtonStyle where Self == PlaidIconButtonStyle {
    static var plaidIcon: PlaidIconButtonStyle { PlaidIconButtonStyle() }
}

// MARK: - Preview

#Preview {
    VStack(spacing: PlaidSpacing.lg) {
        Button("Default Button") {}
            .buttonStyle(.plaid)

        Button("Primary Action") {}
            .buttonStyle(.plaidPrimary)
            .tint(.blue)

        Button("Secondary Action") {}
            .buttonStyle(.plaidSecondary)

        Button("Delete") {}
            .buttonStyle(.plaidDestructive)

        Button {
        } label: {
            Image(systemName: "gear")
        }
        .buttonStyle(.plaidIcon)
    }
    .padding()
}
