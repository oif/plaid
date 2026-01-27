import Foundation

@MainActor
protocol AudioPipelineDelegate: AnyObject {
    func audioPipeline(_ pipeline: AudioPipeline, didUpdateLevel level: Float)
    func audioPipeline(_ pipeline: AudioPipeline, didUpdateWaveform samples: [Float])
}
