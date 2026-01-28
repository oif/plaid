import SwiftUI

struct AudioWaveformView: View {
    let level: Float
    let samples: [Float]
    let barCount: Int
    let spacing: CGFloat
    let cornerRadius: CGFloat
    
    init(level: Float, samples: [Float] = [], barCount: Int = 5, spacing: CGFloat = 4, cornerRadius: CGFloat = 2) {
        self.level = level
        self.samples = samples
        self.barCount = barCount
        self.spacing = spacing
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        level: sampleForBar(index: index),
                        index: index,
                        totalBars: barCount,
                        cornerRadius: cornerRadius,
                        parentHeight: geometry.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func sampleForBar(index: Int) -> Float {
        guard !samples.isEmpty else { return level }
        let sampleIndex = samples.count - barCount + index
        if sampleIndex >= 0 && sampleIndex < samples.count {
            return samples[sampleIndex]
        }
        return level * 0.3
    }
}

private struct WaveformBar: View {
    let level: Float
    let index: Int
    let totalBars: Int
    let cornerRadius: CGFloat
    let parentHeight: CGFloat
    
    private var barHeight: CGFloat {
        let centerIndex = Float(totalBars - 1) / 2.0
        let distance = abs(Float(index) - centerIndex)
        let normalizedDistance = distance / centerIndex
        let falloff = 1.0 - pow(normalizedDistance, 0.7) * 0.85
        let baseHeight: CGFloat = 0.1
        let maxAddition: CGFloat = 0.9
        return baseHeight + CGFloat(level * falloff) * maxAddition
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.tint.opacity(0.8))
            .frame(height: parentHeight * barHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: level)
    }
}

struct CompactWaveformView: View {
    let level: Float
    
    var body: some View {
        AudioWaveformView(level: level, barCount: 3, spacing: 3, cornerRadius: 1.5)
            .frame(width: 20, height: 16)
    }
}

struct RealtimeWaveformView: View {
    let samples: [Float]
    var barCount: Int = 17
    var spacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let sample = sampleAt(index: index)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.foreground.opacity(0.8))
                        .frame(height: max(2, geometry.size.height * CGFloat(sample)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func sampleAt(index: Int) -> Float {
        guard !samples.isEmpty else { return 0.1 }
        let sampleIndex = samples.count - barCount + index
        if sampleIndex >= 0 && sampleIndex < samples.count {
            return max(0.1, samples[sampleIndex])
        }
        return 0.1
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioWaveformView(level: 0.7)
            .frame(width: 60, height: 40)
            .tint(.red)
        
        CompactWaveformView(level: 0.5)
            .tint(.blue)
    }
    .padding()
}
