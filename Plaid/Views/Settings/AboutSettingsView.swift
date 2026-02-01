import SwiftUI
import AppKit

struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                
                VStack(spacing: 6) {
                    Text("Plaid")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(Bundle.main.appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Expand your brain bandwidth.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        aboutFeatureRow(icon: "mic.fill", color: .red, title: "Voice to Text", desc: "Local or cloud-powered speech recognition")
                        aboutFeatureRow(icon: "sparkles", color: .purple, title: "AI Enhancement", desc: "Smart correction with custom prompts")
                        aboutFeatureRow(icon: "globe", color: .blue, title: "Multi-language", desc: "Chinese, English, and more")
                        aboutFeatureRow(icon: "bolt.fill", color: .orange, title: "Instant Typing", desc: "Auto-inject text to any app")
                        aboutFeatureRow(icon: "lock.shield.fill", color: .green, title: "Privacy First", desc: "Local models, your data stays yours")
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        Text("Created by")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Text("Neo")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 16) {
                            Link(destination: URL(string: "https://oo.sb")!) {
                                Label("Website", systemImage: "globe")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            
                            Link(destination: URL(string: "https://twitter.com/neoz_")!) {
                                Label("@neoz_", systemImage: "at")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Text("Built with SwiftUI for macOS")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func aboutFeatureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AboutSettingsView()
        .frame(width: 500, height: 600)
}
