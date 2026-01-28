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
        .frame(width: 120, height: 40)
        .background {
            Capsule()
                .fill(.black)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
    }
    
    private func errorContent(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
            
            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
    }
    
    private var processingContent: some View {
        Text("Thinking...")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
    }
    
    private var durationText: String {
        "\(Int(pillState.recordingDuration))s"
    }
    
    private var recordingContent: some View {
        HStack(spacing: 0) {
            Text(durationText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .padding(.leading, 12)
            
            Spacer(minLength: 0)
            
            waveformView
            
            Spacer(minLength: 0)
            
            Button {
                pillState.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background {
                        Circle()
                            .fill(.white.opacity(cancelHovered ? 0.2 : 0.1))
                    }
            }
            .buttonStyle(.plain)
            .onHover { cancelHovered = $0 }
            .padding(.trailing, 8)
        }
    }
    
    private var waveformView: some View {
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .animation(.easeOut(duration: 0.08), value: pillState.waveformLevels)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < pillState.waveformLevels.count else { return 3 }
        let level = pillState.waveformLevels[index]
        let centerIndex: CGFloat = 4.5
        let distance = abs(CGFloat(index) - centerIndex)
        let falloff = 1.0 - (distance / centerIndex) * 0.3
        let effectiveLevel = pillState.isRecording ? CGFloat(level) : 0.15
        return 4 + effectiveLevel * falloff * 20
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        TranscriptionPillView(pillState: TranscriptionPillState())
    }
    .frame(width: 300, height: 100)
}
