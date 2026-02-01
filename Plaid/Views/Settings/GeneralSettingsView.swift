//
//  GeneralSettingsView.swift
//  Plaid
//
//  General settings tab - auto-inject, language, accessibility, hotkey, updates, audio input.
//

import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var audioInputManager: AudioInputManager
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-inject text after recording", isOn: $settings.autoInject)
                
                Picker("Language", selection: $settings.language) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("Chinese (Simplified)").tag("zh-CN")
                    Text("Chinese (Traditional)").tag("zh-TW")
                    Text("Japanese").tag("ja-JP")
                    Text("Korean").tag("ko-KR")
                    Text("Spanish").tag("es-ES")
                    Text("French").tag("fr-FR")
                    Text("German").tag("de-DE")
                }
                
                HStack {
                    Text("Accessibility Permission")
                    Spacer()
                    if appState.appContext.hasAccessibilityPermission {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Granted")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Grant Access") {
                            appState.appContext.requestAccessibilityPermission()
                        }
                        .buttonStyle(.glassCompat)
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Trigger Key")
                    Spacer()
                    HotkeyRecorder(
                        keyCode: $settings.holdKeyCode,
                        modifiers: $settings.holdModifiers,
                        useFn: $settings.holdUseFn,
                        allowModifierOnly: true
                    )
                }
            } header: {
                Text("Gesture Key")
            }
            
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toggle Mode")
                            .font(.subheadline)
                        Text("Double-tap to start, tap again to stop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "hand.point.down")
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Push-to-Talk")
                            .font(.subheadline)
                        Text("Hold to record, release to stop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text("Both gestures work with the trigger key above.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { SparkleUpdater.shared.automaticallyChecksForUpdates },
                    set: { SparkleUpdater.shared.automaticallyChecksForUpdates = $0 }
                ))
                
                HStack {
                    Button("Check for Updates...") {
                        SparkleUpdater.shared.checkForUpdates()
                    }
                    .disabled(!SparkleUpdater.shared.canCheckForUpdates)
                    
                    Spacer()
                    
                    if let lastCheck = SparkleUpdater.shared.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Audio Input") {
                Picker("Input Device", selection: $audioInputManager.selectedDevice) {
                    ForEach(audioInputManager.availableDevices) { device in
                        HStack {
                            if device.isDefault && device.uid != "system_default" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                            Text(device.name)
                        }
                        .tag(device)
                    }
                }
                
                Button {
                    audioInputManager.refreshDevices()
                } label: {
                    Label("Refresh Devices", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(AppState())
        .environmentObject(AppSettings.shared)
        .environmentObject(AudioInputManager.shared)
        .frame(width: 500, height: 600)
}
