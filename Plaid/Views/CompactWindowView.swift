import SwiftUI

struct CompactWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await appState.toggleRecording()
                }
            } label: {
                ZStack {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18))
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(appState.isRecording ? .red : .accentColor)
            .scaleEffect(isHovering ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .keyboardShortcut("r", modifiers: [.command])
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if appState.isRecording {
                        CompactWaveformView(level: SpeechService.shared.audioLevel)
                            .tint(.red)
                    }
                    
                    Text(compactStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: appState.settings.sttProvider.icon)
                        .font(.caption2)
                    Text(appState.settings.sttProvider.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 200)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    private var compactStatus: String {
        if appState.isRecording {
            return "Recording..."
        } else if appState.isProcessing {
            return appState.statusMessage
        } else {
            return "Ready"
        }
    }
}

#Preview {
    CompactWindowView()
        .environmentObject(AppState())
}
