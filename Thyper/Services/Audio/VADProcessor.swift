import Foundation
import AVFoundation

struct VADResult {
    let level: Float
    let peakLevel: Float
    let isSpeech: Bool
}

class VADProcessor {
    private let speechThreshold: Float = 0.02
    private let silenceThreshold: Float = 0.008
    private var speechFrameCount = 0
    private var silenceFrameCount = 0
    private let minSpeechFrames = 3
    private let minSilenceFrames = 10
    private var isSpeechActive = false
    
    init() {}
    
    func start() {
        reset()
    }
    
    func reset() {
        speechFrameCount = 0
        silenceFrameCount = 0
        isSpeechActive = false
    }
    
    func process(buffer: AVAudioPCMBuffer) -> VADResult {
        guard let channelData = buffer.floatChannelData?[0] else {
            return VADResult(level: 0, peakLevel: 0, isSpeech: false)
        }
        
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        var maxSample: Float = 0
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample * sample
            if sample > maxSample { maxSample = sample }
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        if rms > speechThreshold {
            speechFrameCount += 1
            silenceFrameCount = 0
            if speechFrameCount >= minSpeechFrames {
                isSpeechActive = true
            }
        } else if rms < silenceThreshold {
            silenceFrameCount += 1
            speechFrameCount = 0
            if silenceFrameCount >= minSilenceFrames {
                isSpeechActive = false
            }
        }
        
        return VADResult(
            level: rms,
            peakLevel: maxSample,
            isSpeech: isSpeechActive
        )
    }
    
    static func analyzeAudioFile(at url: URL) -> Bool {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return true
        }
        
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return true
        }
        
        do {
            try audioFile.read(into: buffer)
        } catch {
            return true
        }
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return true
        }
        
        var sum: Float = 0
        var speechSamples = 0
        let threshold: Float = 0.015
        
        for i in 0..<Int(buffer.frameLength) {
            let sample = abs(channelData[i])
            sum += sample * sample
            if sample > threshold {
                speechSamples += 1
            }
        }
        
        let rms = sqrt(sum / Float(buffer.frameLength))
        let speechRatio = Float(speechSamples) / Float(buffer.frameLength)
        
        return rms > 0.01 && speechRatio > 0.05
    }
}
