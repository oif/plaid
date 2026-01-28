import Foundation
import AVFoundation
import Accelerate

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
        
        let frameLength = vDSP_Length(buffer.frameLength)
        
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)
        
        var maxSample: Float = 0
        vDSP_maxmgv(channelData, 1, &maxSample, frameLength)
        
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
        
        let frameLength = vDSP_Length(buffer.frameLength)
        
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)
        
        let threshold: Float = 0.015
        var speechSamples: vDSP_Length = 0
        var absBuffer = [Float](repeating: 0, count: Int(buffer.frameLength))
        vDSP_vabs(channelData, 1, &absBuffer, 1, frameLength)
        
        for i in 0..<Int(buffer.frameLength) {
            if absBuffer[i] > threshold {
                speechSamples += 1
            }
        }
        
        let speechRatio = Float(speechSamples) / Float(buffer.frameLength)
        
        return rms > 0.01 && speechRatio > 0.05
    }
}
