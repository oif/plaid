import Foundation
import Speech
import AVFoundation

// MARK: - Multipart Form Builder

private struct MultipartFormBuilder {
    let boundary: String
    private var data = Data()
    
    init() {
        self.boundary = UUID().uuidString
    }
    
    mutating func addField(name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func addFile(name: String, filename: String, contentType: String, fileData: Data) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }
    
    func build() -> Data {
        var result = data
        result.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return result
    }
    
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}

// MARK: - STT Service

@MainActor
class STTService: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    private var tempFileURL: URL?
    
    var currentTranscription = ""
    var onPartialResult: ((String) -> Void)?
    
    @Published var audioLevel: Float = 0
    @Published var waveformSamples: [Float] = []
    
    init() {
        let settings = AppSettings.shared
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.language))
    }
    
    func initialize() async throws {
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            throw STTError.notAuthorized
        }
        
        let micStatus = await AVCaptureDevice.requestAccess(for: .audio)
        guard micStatus else {
            throw STTError.microphoneNotAuthorized
        }
    }
    
    func startListening(onPartial: @escaping (String) -> Void) async throws {
        cleanup()
        
        let settings = AppSettings.shared
        
        switch settings.sttProvider {
        case .appleSpeech:
            try await startAppleSpeechRecording(onPartial: onPartial)
        case .sherpaLocal:
            try await startSherpaRecording()
        case .whisperAPI, .elevenLabs, .soniox, .glmASR, .customAPI:
            try await startAPIRecording()
        }
        
        self.onPartialResult = onPartial
    }
    
    private func cleanup() {
        audioEngine?.stop()
        if audioEngine?.inputNode.numberOfInputs ?? 0 > 0 {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        currentTranscription = ""
        audioLevel = 0
        waveformSamples = []
        
        if let fileURL = tempFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }
    }
    
    private func startAppleSpeechRecording(onPartial: @escaping (String) -> Void) async throws {
        let settings = AppSettings.shared
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: settings.language))
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw STTError.audioEngineError
        }
        
        try AudioInputManager.shared.setInputDevice(for: audioEngine, device: AudioInputManager.shared.selectedDevice)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw STTError.requestError
        }
        
        request.shouldReportPartialResults = true
        
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        
        if #available(macOS 13, *) {
            request.addsPunctuation = true
        }
        
        currentTranscription = ""
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                self?.currentTranscription = text
                
                Task { @MainActor in
                    onPartial(text)
                }
            }
            
            if error != nil || result?.isFinal == true {
                self?.audioEngine?.stop()
                self?.audioEngine?.inputNode.removeTap(onBus: 0)
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 735, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.calculateAudioLevel(buffer: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startAPIRecording() async throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw STTError.audioEngineError
        }
        
        try AudioInputManager.shared.setInputDevice(for: audioEngine, device: AudioInputManager.shared.selectedDevice)
        
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("thyper_\(UUID().uuidString).wav")
        
        guard let fileURL = tempFileURL else {
            throw STTError.fileError
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw STTError.audioEngineError
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 735, format: inputFormat) { [weak self] buffer, _ in
            self?.calculateAudioLevel(buffer: buffer)
            
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * 16000 / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if error == nil {
                try? audioFile.write(from: convertedBuffer)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func startSherpaRecording() async throws {
        let selectedModel = await ModelManager.shared.selectedModel
        guard ModelManager.shared.isModelAvailable(selectedModel) else {
            throw STTError.configError
        }
        
        if !SherpaOnnxService.shared.isReady {
            try SherpaOnnxService.shared.initialize(with: selectedModel)
        }
        try await startAPIRecording()
    }
    
    private func transcribeWithSherpa() async throws -> String {
        guard let fileURL = tempFileURL else {
            throw STTError.fileError
        }
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }
        
        let text = try SherpaOnnxService.shared.transcribe(fileURL: fileURL)
        return text
    }
    
    func stopListening() async throws -> String {
        let settings = AppSettings.shared
        
        audioEngine?.stop()
        if audioEngine?.inputNode.numberOfInputs ?? 0 > 0 {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        
        if settings.sttProvider != .appleSpeech,
           let fileURL = tempFileURL {
            if SileroVADService.shared.isModelAvailable {
                let hasSpeech = SileroVADService.shared.containsSpeech(fileURL: fileURL)
                if !hasSpeech {
                    print("STTService: No speech detected, skipping")
                    try? FileManager.default.removeItem(at: fileURL)
                    tempFileURL = nil
                    audioEngine = nil
                    recognitionRequest = nil
                    recognitionTask = nil
                    return ""
                }
            }
            
            if SpeechDenoiserService.shared.isModelAvailable {
                do {
                    let denoisedURL = try SpeechDenoiserService.shared.denoise(fileURL: fileURL)
                    try? FileManager.default.removeItem(at: fileURL)
                    tempFileURL = denoisedURL
                    print("STTService: Audio denoised")
                } catch {
                    print("STTService: Denoising failed: \(error), using original")
                }
            }
        }
        
        let result: String
        
        switch settings.sttProvider {
        case .appleSpeech:
            try? await Task.sleep(nanoseconds: 300_000_000)
            result = currentTranscription
        case .sherpaLocal:
            result = try await transcribeWithSherpa()
        case .whisperAPI, .customAPI:
            result = try await transcribeWithAPI()
        case .elevenLabs:
            result = try await transcribeWithElevenLabs()
        case .soniox:
            result = try await transcribeWithSoniox()
        case .glmASR:
            result = try await transcribeWithGLM()
        }
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        return result
    }
    
    private func transcribeWithAPI() async throws -> String {
        let (audioData, settings) = try prepareTranscription()
        
        let endpoint = settings.effectiveSTTEndpoint
        let apiKey = settings.effectiveSTTApiKey
        
        guard !endpoint.isEmpty, !apiKey.isEmpty, let url = URL(string: endpoint) else {
            throw STTError.configError
        }
        
        var form = MultipartFormBuilder()
        form.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: audioData)
        form.addField(name: "model", value: settings.sttProvider == .customAPI ? settings.customSTTModel : "whisper-1")
        if settings.language != "auto" {
            form.addField(name: "language", value: settings.language.components(separatedBy: "-").first ?? settings.language)
        }
        
        return try await sendTranscriptionRequest(url: url, apiKey: apiKey, authHeader: "Authorization", authPrefix: "Bearer ", form: form)
    }
    
    private func transcribeWithElevenLabs() async throws -> String {
        let (audioData, settings) = try prepareTranscription()
        let apiKey = settings.elevenLabsApiKey
        
        guard !apiKey.isEmpty, let url = URL(string: "https://api.elevenlabs.io/v1/speech-to-text") else {
            throw STTError.configError
        }
        
        var form = MultipartFormBuilder()
        form.addField(name: "model_id", value: "scribe_v1")
        form.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: audioData)
        form.addField(name: "language_code", value: settings.language.components(separatedBy: "-").first ?? "en")
        
        return try await sendTranscriptionRequest(url: url, apiKey: apiKey, authHeader: "xi-api-key", authPrefix: "", form: form, timeout: 120)
    }
    
    private func transcribeWithGLM() async throws -> String {
        let (audioData, settings) = try prepareTranscription()
        let apiKey = settings.glmApiKey
        
        guard !apiKey.isEmpty, let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/audio/transcriptions") else {
            throw STTError.configError
        }
        
        var form = MultipartFormBuilder()
        form.addField(name: "model", value: "glm-asr-2512")
        form.addField(name: "stream", value: "false")
        form.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", fileData: audioData)
        
        return try await sendTranscriptionRequest(url: url, apiKey: apiKey, authHeader: "Authorization", authPrefix: "Bearer ", form: form)
    }
    
    private func prepareTranscription() throws -> (Data, AppSettings) {
        guard let fileURL = tempFileURL else {
            throw STTError.fileError
        }
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }
        
        let audioData = try Data(contentsOf: fileURL)
        return (audioData, AppSettings.shared)
    }
    
    private func sendTranscriptionRequest(url: URL, apiKey: String, authHeader: String, authPrefix: String, form: MultipartFormBuilder, timeout: TimeInterval = 60) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("\(authPrefix)\(apiKey)", forHTTPHeaderField: authHeader)
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = form.build()
        
        let (data, response) = try await NetworkSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.apiError
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorStr = String(data: data, encoding: .utf8) {
                throw STTError.serverError(errorStr)
            }
            throw STTError.httpError(httpResponse.statusCode)
        }
        
        struct TextResponse: Decodable { let text: String }
        return try JSONDecoder().decode(TextResponse.self, from: data).text
    }
    
    private func transcribeWithSoniox() async throws -> String {
        guard let fileURL = tempFileURL else {
            throw STTError.fileError
        }
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }
        
        let audioData = try Data(contentsOf: fileURL)
        let settings = AppSettings.shared
        let apiKey = settings.sonioxApiKey
        
        guard !apiKey.isEmpty else {
            throw STTError.configError
        }
        
        let boundary = UUID().uuidString
        var uploadRequest = URLRequest(url: URL(string: "https://api.soniox.com/v1/files")!)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.timeoutInterval = 120
        
        var uploadBody = Data()
        uploadBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        uploadBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        uploadBody.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        uploadBody.append(audioData)
        uploadBody.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        uploadRequest.httpBody = uploadBody
        
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        
        guard let uploadHttpResponse = uploadResponse as? HTTPURLResponse, uploadHttpResponse.statusCode == 200 || uploadHttpResponse.statusCode == 201 else {
            if let errorStr = String(data: uploadData, encoding: .utf8) {
                throw STTError.serverError("Upload failed: \(errorStr)")
            }
            throw STTError.apiError
        }
        
        struct FileUploadResponse: Decodable {
            let id: String
        }
        
        let fileResponse = try JSONDecoder().decode(FileUploadResponse.self, from: uploadData)
        let fileId = fileResponse.id
        
        let langHint = settings.language.components(separatedBy: "-").first ?? "en"
        let transcribeBody: [String: Any] = [
            "model": "stt-async-v3",
            "file_id": fileId,
            "language_hints": [langHint]
        ]
        
        var transcribeRequest = URLRequest(url: URL(string: "https://api.soniox.com/v1/transcriptions")!)
        transcribeRequest.httpMethod = "POST"
        transcribeRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        transcribeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        transcribeRequest.httpBody = try JSONSerialization.data(withJSONObject: transcribeBody)
        transcribeRequest.timeoutInterval = 30
        
        let (transcribeData, transcribeResponse) = try await URLSession.shared.data(for: transcribeRequest)
        
        guard let transcribeHttpResponse = transcribeResponse as? HTTPURLResponse, transcribeHttpResponse.statusCode == 200 || transcribeHttpResponse.statusCode == 201 else {
            if let errorStr = String(data: transcribeData, encoding: .utf8) {
                throw STTError.serverError("Transcription create failed: \(errorStr)")
            }
            throw STTError.apiError
        }
        
        struct TranscriptionJobResponse: Decodable {
            let id: String
            let status: String
        }
        
        let jobResponse = try JSONDecoder().decode(TranscriptionJobResponse.self, from: transcribeData)
        let jobId = jobResponse.id
        
        var status = jobResponse.status
        let maxAttempts = 60
        var attempts = 0
        
        while status != "completed" && status != "error" && attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            attempts += 1
            
            var statusRequest = URLRequest(url: URL(string: "https://api.soniox.com/v1/transcriptions/\(jobId)")!)
            statusRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            let statusResponse = try JSONDecoder().decode(TranscriptionJobResponse.self, from: statusData)
            status = statusResponse.status
        }
        
        guard status == "completed" else {
            throw STTError.serverError("Transcription failed or timed out: \(status)")
        }
        
        var resultRequest = URLRequest(url: URL(string: "https://api.soniox.com/v1/transcriptions/\(jobId)/transcript")!)
        resultRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (resultData, resultResponse) = try await URLSession.shared.data(for: resultRequest)
        
        guard let resultHttpResponse = resultResponse as? HTTPURLResponse, resultHttpResponse.statusCode == 200 else {
            throw STTError.apiError
        }
        
        struct SonioxToken: Decodable {
            let text: String
        }
        
        struct SonioxTranscript: Decodable {
            let tokens: [SonioxToken]
        }
        
        let transcript = try JSONDecoder().decode(SonioxTranscript.self, from: resultData)
        return transcript.tokens.map { $0.text }.joined()
    }
    
    func cancel() {
        cleanup()
    }
    
    func transcribeFile(at url: URL) async throws -> String {
        let settings = AppSettings.shared
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempCopy = tempDir.appendingPathComponent("thyper_import_\(UUID().uuidString).wav")
        try FileManager.default.copyItem(at: url, to: tempCopy)
        tempFileURL = tempCopy
        

        
        switch settings.sttProvider {
        case .appleSpeech:
            throw STTError.configError
        case .sherpaLocal:
            return try await transcribeWithSherpa()
        case .whisperAPI, .customAPI:
            return try await transcribeWithAPI()
        case .elevenLabs:
            return try await transcribeWithElevenLabs()
        case .soniox:
            return try await transcribeWithSoniox()
        case .glmASR:
            return try await transcribeWithGLM()
        }
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        var maxSample: Float = 0
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample * sample
            if sample > maxSample { maxSample = sample }
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let level = min(1.0, rms * 5)
        let capturedMaxSample = maxSample
        
        Task { @MainActor in
            self.audioLevel = level
            
            let normalizedSample = min(1.0, capturedMaxSample * 3)
            self.waveformSamples.append(normalizedSample)
            if self.waveformSamples.count > 40 {
                self.waveformSamples.removeFirst()
            }
        }
    }
}

enum STTError: Error, LocalizedError {
    case notAuthorized
    case microphoneNotAuthorized
    case audioEngineError
    case requestError
    case fileError
    case apiError
    case configError
    case invalidEndpoint
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition not authorized"
        case .microphoneNotAuthorized: return "Microphone access not authorized"
        case .audioEngineError: return "Audio engine error"
        case .requestError: return "Recognition request error"
        case .fileError: return "Audio file error"
        case .apiError: return "API error"
        case .configError: return "API not configured"
        case .invalidEndpoint: return "Invalid API endpoint"
        case .httpError(let code): return "HTTP error: \(code)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}
