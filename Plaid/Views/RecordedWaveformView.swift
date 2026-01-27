import SwiftUI

struct RecordedWaveformView: View {
    let samples: [Float]
    var barWidth: CGFloat = 2
    var barSpacing: CGFloat = 1
    var cornerRadius: CGFloat = 1
    var color: Color = .accentColor
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(Array(resampledData(for: geometry.size.width).enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(color.opacity(0.7))
                        .frame(width: barWidth, height: max(2, geometry.size.height * CGFloat(sample)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func resampledData(for width: CGFloat) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        let targetCount = Int(width / (barWidth + barSpacing))
        guard targetCount > 0 else { return [] }
        
        if samples.count <= targetCount {
            return samples
        }
        
        var result: [Float] = []
        let chunkSize = Float(samples.count) / Float(targetCount)
        
        for i in 0..<targetCount {
            let startIndex = Int(Float(i) * chunkSize)
            let endIndex = min(Int(Float(i + 1) * chunkSize), samples.count)
            
            if startIndex < endIndex {
                let chunk = samples[startIndex..<endIndex]
                let maxVal = chunk.max() ?? 0
                result.append(maxVal)
            }
        }
        
        return result
    }
}

#Preview {
    let sampleData: [Float] = (0..<100).map { _ in Float.random(in: 0.1...1.0) }
    
    VStack(spacing: 20) {
        RecordedWaveformView(samples: sampleData)
            .frame(height: 40)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        
        RecordedWaveformView(samples: sampleData, color: .red)
            .frame(height: 60)
            .padding()
    }
    .padding()
}
