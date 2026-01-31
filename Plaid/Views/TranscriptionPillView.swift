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
        HStack(spacing: 8) {
            thinkingBarsView
            
            Text("Thinking")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
    }
    
    // MARK: - Bar Loader
    
    private static let barDelays: [Double] = [0.0, 0.10, 0.20]
    private static let waveDuration: Double = 0.6
    private static let hueCycleDuration: Double = 6.5
    private static let barHeight: CGFloat = 12
    private static let barWidth: CGFloat = 3.5
    private static let barSpacing: CGFloat = 2
    
    private var thinkingBarsView: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let hue = (time / Self.hueCycleDuration).truncatingRemainder(dividingBy: 1.0)
            
            let opacities = Self.barDelays.map { delay in
                barOpacity(time: time, delay: delay)
            }
            let avgOpacity = opacities.reduce(0, +) / Double(opacities.count)
            
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hue: hue, saturation: 0.4, brightness: 1.0))
                    .frame(width: 16, height: 16)
                    .blur(radius: 6)
                    .opacity(avgOpacity * 0.6)
                
                HStack(spacing: Self.barSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        let opacity = opacities[index]
                        let brightness = 0.3 + opacity * 0.7
                        let widthScale = 0.5 + opacity * 0.5
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(hue: hue, saturation: 0.35, brightness: brightness))
                            .frame(width: Self.barWidth * widthScale, height: Self.barHeight)
                            .opacity(opacity)
                    }
                }
            }
        }
    }
    
    private func barOpacity(time: Double, delay: Double) -> Double {
        let phase = ((time - delay) / Self.waveDuration) * 2 * .pi
        let raw = (sin(phase) + 1) / 2
        let minOpacity = 0.15
        return minOpacity + raw * (1.0 - minOpacity)
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
