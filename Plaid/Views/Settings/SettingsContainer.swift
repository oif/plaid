//
//  SettingsContainer.swift
//  Plaid
//
//  Shared components for Settings views.
//

import SwiftUI

// MARK: - Settings Section Header

struct SettingsSectionHeader: View {
    let title: String
    let icon: String?
    
    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: PlaidSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(PlaidTypography.badge)
                .foregroundStyle(.tertiary)
                .tracking(0.5)
        }
        .textCase(.uppercase)
    }
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let label: String
    let icon: String?
    let content: Content
    
    init(_ label: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            Text(label)
            Spacer()
            content
        }
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(PlaidSpacing.lg)
            .background(
                PlaidColors.Background.secondary,
                in: RoundedRectangle(cornerRadius: PlaidRadius.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PlaidRadius.lg)
                    .strokeBorder(.secondary.opacity(PlaidOpacity.subtle), lineWidth: 1)
            )
    }
}

// MARK: - Previews

#Preview("Section Header") {
    VStack(alignment: .leading, spacing: 16) {
        SettingsSectionHeader("Behavior")
        SettingsSectionHeader("Updates", icon: "arrow.clockwise")
    }
    .padding()
}

#Preview("Settings Row") {
    VStack(spacing: 12) {
        SettingsRow("Language", icon: "globe") {
            Text("English")
                .foregroundStyle(.secondary)
        }
        SettingsRow("Auto-inject") {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
    }
    .padding()
}

#Preview("Settings Card") {
    SettingsCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Title")
                .font(.headline)
            Text("Card content goes here")
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
