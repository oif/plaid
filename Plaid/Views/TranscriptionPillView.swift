import SwiftUI

struct TranscriptionPillView: View {
    @ObservedObject var pillState: TranscriptionPillState
    
    private var pillWidth: CGFloat {
        pillState.showModeSelector ? 240 : 130
    }
    
    var body: some View {
        VStack(spacing: 8) {
            mainPill
            
            if pillState.showModeSelector {
                modeSelectorView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pillState.showModeSelector)
        .animation(.easeInOut(duration: 0.2), value: pillState.isProcessing)
        .animation(.easeInOut(duration: 0.2), value: pillState.errorMessage)
    }
    
    private var mainPill: some View {
        pillContent
            .frame(width: pillWidth, height: 40)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.85))
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }
    
    @ViewBuilder
    private var pillContent: some View {
        if let notice = pillState.fallbackNotice {
            Text(notice)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        } else if let error = pillState.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        } else if pillState.isProcessing {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white)
                
                Text("Thinking...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        } else {
            recordingContent
        }
    }
    
    private var recordingContent: some View {
        HStack(spacing: 0) {
            Button {
                pillState.toggleModeSelector()
            } label: {
                Text(pillState.currentMode.icon)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(.white.opacity(pillState.showModeSelector ? 0.25 : 0.15)))
            
            Spacer()
            
            waveformIndicator
            
            Spacer()
            
            Button {
                pillState.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(.white.opacity(0.15)))
        }
        .padding(.horizontal, 10)
    }
    
    private var waveformIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                WaveformBar(
                    height: barHeight(for: index),
                    isRecording: pillState.isRecording
                )
            }
        }
        .frame(width: 56, height: 26)
        .animation(.easeOut(duration: 0.08), value: pillState.waveformLevels)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let level = pillState.waveformLevels[safe: index] ?? 0.1
        let centerIndex: CGFloat = 5.5
        let distance = abs(CGFloat(index) - centerIndex)
        let falloff = 1.0 - (distance / centerIndex) * 0.25
        let effectiveLevel = pillState.isRecording ? CGFloat(level) : 0.15
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 24
        return minHeight + effectiveLevel * falloff * (maxHeight - minHeight)
    }
    
    private var modeSelectorView: some View {
        VStack(spacing: 4) {
            ForEach(AppSettings.shared.allModes) { mode in
                ModeRowView(
                    mode: mode,
                    isSelected: pillState.currentMode.id == mode.id,
                    isAvailable: pillState.isModeAvailable(mode)
                ) {
                    if pillState.isModeAvailable(mode) {
                        pillState.selectMode(mode)
                    }
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }
}

private struct ModeRowView: View {
    let mode: Mode
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(mode.icon)
                    .font(.system(size: 16))
                
                Text(mode.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isAvailable ? .white : .white.opacity(0.4))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                if !isAvailable {
                    Text("需选中文本")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

private struct WaveformBar: View {
    let height: CGFloat
    let isRecording: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(.white.opacity(isRecording ? 1.0 : 0.6))
            .frame(width: 3, height: height)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.5)
        TranscriptionPillView(pillState: TranscriptionPillState())
    }
    .frame(width: 300, height: 200)
}
