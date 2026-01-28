import SwiftUI
import AppKit

struct DiagnosticsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SYSTEM STATUS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        DiagnosticStatusRow(
                            title: "Accessibility",
                            status: DiagnosticsManager.shared.isAccessibilityGranted ? "Granted" : "Denied",
                            isOK: DiagnosticsManager.shared.isAccessibilityGranted,
                            action: DiagnosticsManager.shared.isAccessibilityGranted ? nil : {
                                DiagnosticsManager.shared.requestAccessibilityPermission()
                            },
                            actionLabel: "Grant Access"
                        )
                        
                        DiagnosticStatusRow(
                            title: "Event Tap",
                            status: DiagnosticsManager.shared.eventTapStatus.rawValue,
                            isOK: DiagnosticsManager.shared.eventTapStatus == .active,
                            action: DiagnosticsManager.shared.eventTapStatus != .active ? {
                                GlobalHotkeyManager.shared.restart()
                            } : nil,
                            actionLabel: "Restart"
                        )
                        
                        if let error = DiagnosticsManager.shared.lastEventTapError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("HOTKEY CONFIGURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        HStack {
                            Text("Key Code")
                            Spacer()
                            Text("\(AppSettings.shared.hotkeyKeyCode)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Text("Use Fn Key")
                            Spacer()
                            Text(AppSettings.shared.hotkeyUseFn ? "Yes" : "No")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let fnUsageType = UserDefaults.standard.persistentDomain(forName: "com.apple.HIToolbox")?["AppleFnUsageType"] as? Int, fnUsageType == 3, AppSettings.shared.hotkeyUseFn {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fn Key Conflict Detected")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("System fn key is set to 'Start Dictation'. Change it in System Settings > Keyboard > Keyboard Shortcuts > Function Keys.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LOGS & EXPORT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        HStack(spacing: 12) {
                            Button {
                                copyDiagnosticsToClipboard()
                            } label: {
                                Label("Copy Diagnostics", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.glassCompat)
                            
                            Button {
                                exportLogsToFile()
                            } label: {
                                Label("Export Logs", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.glassCompat)
                            
                            Button {
                                DiagnosticsManager.shared.clearLogs()
                            } label: {
                                Label("Clear Logs", systemImage: "trash")
                            }
                            .buttonStyle(.glassCompat)
                        }
                        
                        Text("Logs are stored in Application Support/Plaid/plaid.log")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func copyDiagnosticsToClipboard() {
        let diagnostics = DiagnosticsManager.shared.exportDiagnostics()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }
    
    private func exportLogsToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "plaid-diagnostics-\(Date().ISO8601Format()).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            let diagnostics = DiagnosticsManager.shared.exportDiagnostics()
            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Diagnostic Status Row

struct DiagnosticStatusRow: View {
    let title: String
    let status: String
    let isOK: Bool
    var action: (() -> Void)?
    var actionLabel: String = "Fix"
    
    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .red)
            
            Text(title)
            
            Spacer()
            
            Text(status)
                .foregroundStyle(.secondary)
            
            if let action = action {
                Button(actionLabel, action: action)
                    .buttonStyle(.glassCompat)
                    .controlSize(.small)
            }
        }
    }
}

#Preview {
    DiagnosticsSettingsView()
        .frame(width: 500, height: 600)
}
