import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.neospaceindustries.plaid", category: "Pill")

@MainActor
class TranscriptionPillState: ObservableObject {
    @Published var isVisible = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var waveformLevels: [Float] = Array(repeating: 0.1, count: 12)
    @Published var recordingDuration: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var durationCancellable: AnyCancellable?
    
    var onComplete: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onHide: (() -> Void)?
    
    init() {
        SpeechService.shared.$waveformLevels
            .receive(on: RunLoop.main)
            .sink { [weak self] levels in
                guard self?.isRecording == true else { return }
                self?.waveformLevels = levels
            }
            .store(in: &cancellables)
        
        SpeechService.shared.$isProcessing
            .receive(on: RunLoop.main)
            .sink { [weak self] processing in
                self?.isProcessing = processing
            }
            .store(in: &cancellables)
    }
    
    func show() {
        logger.info("show: isVisible→true, starting recording")
        isVisible = true
        startRecording()
    }
    
    func hide() {
        isVisible = false
        isRecording = false
        isProcessing = false
        errorMessage = nil
        waveformLevels = Array(repeating: 0.1, count: 12)
        recordingDuration = 0
        stopDurationTimer()
        onHide?()
    }
    
    func toggle() {
        if isVisible {
            if isRecording {
                complete()
            } else if !isProcessing {
                cancel()
            }
        } else {
            show()
        }
    }
    
    func startRecording() {
        isRecording = true
        errorMessage = nil
        recordingDuration = 0
        startDurationTimer()
        logger.info("startRecording: launching SpeechService.startListening")
        
        Task {
            do {
                try await SpeechService.shared.startListening()
                logger.info("startRecording: listening started")
            } catch {
                logger.error("startRecording failed: \(error.localizedDescription)")
                isRecording = false
                stopDurationTimer()
                showError(friendlyError(error))
            }
        }
    }
    
    private func startDurationTimer() {
        let start = Date()
        durationCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recordingDuration = Date().timeIntervalSince(start)
            }
    }
    
    private func stopDurationTimer() {
        durationCancellable?.cancel()
        durationCancellable = nil
    }
    
    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("model") || msg.contains("config") {
            return "Model not ready"
        } else if msg.contains("microphone") || msg.contains("audio") {
            return "Mic unavailable"
        }
        return "Start failed"
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if errorMessage == message {
                hide()
            }
        }
    }
    
    func complete() {
        guard isRecording else {
            hide()
            return
        }
        
        isRecording = false
        isProcessing = true
        stopDurationTimer()
        
        Task {
            do {
                let result = try await SpeechService.shared.stopListening()
                hide()
                if !result.finalText.isEmpty {
                    onComplete?(result.finalText)
                }
            } catch {
                hide()
            }
        }
    }
    
    func cancel() {
        SpeechService.shared.cancel()
        hide()
        onCancel?()
    }
}
