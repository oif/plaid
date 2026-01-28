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
                    let barLevel = sampleForBar(index: index)
                    let centerIndex = Float(barCount - 1) / 2.0
                    let distance = abs(Float(index) - centerIndex)
                    let normalizedDistance = distance / centerIndex
                    let falloff = 1.0 - pow(normalizedDistance, 0.7) * 0.85
                    let height = 0.1 + CGFloat(barLevel * falloff) * 0.9
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.tint.opacity(0.8))
                        .frame(height: geometry.size.height * height)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .animation(.easeOut(duration: 0.08), value: barLevel)
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

struct CompactWaveformView: View {
    let level: Float
    
    var body: some View {
        AudioWaveformView(level: level, barCount: 3, spacing: 3, cornerRadius: 1.5)
            .frame(width: 20, height: 16)
    }
}
