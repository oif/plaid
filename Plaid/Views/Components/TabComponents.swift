import SwiftUI

// MARK: - Main Tab Enum

enum MainTab: String, CaseIterable {
    case home = "Home"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .settings: return "slider.horizontal.3"
        }
    }
}

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case speech = "Speech"
    case vocabulary = "Vocabulary"
    case integrations = "Integrations"
    case diagnostics = "Diagnostics"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .speech: return "waveform"
        case .vocabulary: return "character.book.closed"
        case .integrations: return "puzzlepiece.extension"
        case .diagnostics: return "stethoscope"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Tab Switcher

struct TabSwitcher: View {
    @Binding var selectedTab: MainTab
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: PlaidSpacing.xs) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(PlaidSpacing.xs)
        .glassPill()
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PlaidSpacing.sm - 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary.opacity(0.8) : Color.secondary))
            .padding(.horizontal, PlaidSpacing.lg)
            .padding(.vertical, PlaidSpacing.sm)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                } else if isHovered {
                    Capsule()
                        .fill(.secondary.opacity(PlaidOpacity.subtle))
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
