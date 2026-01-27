import SwiftUI

struct TranscriptionPillView: View {
    @ObservedObject var pillState: TranscriptionPillState
    
    var body: some View {
        pillContent
            .frame(width: 130, height: 40)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.85))
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .animation(.easeInOut(duration: 0.2), value: pillState.isProcessing)
            .animation(.easeInOut(duration: 0.2), value: pillState.errorMessage)
    }
    
    @ViewBuilder
    private var pillContent: some View {
        if let error = pillState.errorMessage {
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
                
                Text("Processing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        } else {
            recordingContent
        }
    }
    
    private var recordingContent: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .padding(.leading, 14)
            
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
            .padding(.trailing, 8)
        }
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
