import SwiftUI

struct IntegrationsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Connect Plaid to powerful third-party services")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                IntegrationCard(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "Claude Agent",
                    description: "Voice-controlled autonomous AI for research, analysis, and complex tasks",
                    status: .comingSoon
                )
                
                IntegrationCard(
                    icon: "macwindow.on.rectangle",
                    iconColor: .blue,
                    title: "Computer Use",
                    description: "Control your Mac with voice - open apps, click, navigate",
                    status: .comingSoon
                )
                
                IntegrationCard(
                    icon: "server.rack",
                    iconColor: .cyan,
                    title: "MCP Servers",
                    description: "Connect to Model Context Protocol servers for extended capabilities",
                    status: .comingSoon
                )
            }
            .padding(16)
        }
    }
}

// MARK: - Integration Card

enum IntegrationStatus {
    case available
    case comingSoon
    case beta
}

struct IntegrationCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: IntegrationStatus
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    
                    statusBadge
                }
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if status == .available {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .available:
            EmptyView()
        case .comingSoon:
            Text("Coming soon")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15), in: Capsule())
        case .beta:
            Text("Beta")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15), in: Capsule())
        }
    }
}

#Preview {
    IntegrationsSettingsView()
        .frame(width: 500, height: 400)
}
