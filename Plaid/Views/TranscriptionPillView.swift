import SwiftUI

struct TranscriptionPillView: View {
    @ObservedObject var pillState: TranscriptionPillState
    
    @State private var cancelHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            if let error = pillState.errorMessage {
                errorContent(error)
            } else if pillState.isProcessing {
                processingContent
            } else {
                recordingContent
            }
        }
        .frame(height: 36)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
    }
    
    private func errorContent(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
            
            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
    }
    
    private var processingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.secondary)
            
            Text("Thinking...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
    }
    
    private var recordingContent: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .padding(.leading, 14)
            
            waveformView
                .frame(width: 60)
                .padding(.horizontal, 12)
            
            Button {
                pillState.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(.quaternary.opacity(cancelHovered ? 1 : 0.5))
                    }
            }
            .buttonStyle(.plain)
            .onHover { cancelHovered = $0 }
            .padding(.trailing, 6)
        }
    }
    
    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.primary.opacity(0.6))
                    .frame(width: 2, height: barHeight(for: index))
            }
        }
        .animation(.easeOut(duration: 0.08), value: pillState.waveformLevels)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < pillState.waveformLevels.count else { return 4 }
        let level = pillState.waveformLevels[index]
        let centerIndex: CGFloat = 5.5
        let distance = abs(CGFloat(index) - centerIndex)
        let falloff = 1.0 - (distance / centerIndex) * 0.3
        let effectiveLevel = pillState.isRecording ? CGFloat(level) : 0.15
        return 4 + effectiveLevel * falloff * 14
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        TranscriptionPillView(pillState: TranscriptionPillState())
    }
    .frame(width: 300, height: 100)
}
