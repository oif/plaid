import Foundation
import SwiftUI

// MARK: - Model Type

enum ModelType: String, Codable {
    case sensevoice
    case whisper
}

// MARK: - Local Model Definition

enum LocalModel: String, CaseIterable, Codable, Identifiable {
    case sensevoiceInt8 = "sensevoice-int8"
    case sensevoiceFp32 = "sensevoice-fp32"
    case whisperTiny = "whisper-tiny"
    case whisperBase = "whisper-base"
    case whisperSmall = "whisper-small"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sensevoiceInt8: return "SenseVoice (INT8)"
        case .sensevoiceFp32: return "SenseVoice (FP32)"
        case .whisperTiny: return "Whisper Tiny"
        case .whisperBase: return "Whisper Base"
        case .whisperSmall: return "Whisper Small"
        }
    }
    
    var sizeDescription: String {
        switch self {
        case .sensevoiceInt8: return "228 MB"
        case .sensevoiceFp32: return "900 MB"
        case .whisperTiny: return "75 MB"
        case .whisperBase: return "145 MB"
        case .whisperSmall: return "488 MB"
        }
    }
    
    var modelType: ModelType {
        switch self {
        case .sensevoiceInt8, .sensevoiceFp32:
            return .sensevoice
        case .whisperTiny, .whisperBase, .whisperSmall:
            return .whisper
        }
    }
    
    var languages: [String] {
        switch self {
        case .sensevoiceInt8, .sensevoiceFp32:
            return ["zh", "en", "ja", "ko", "yue"]  // Chinese, English, Japanese, Korean, Cantonese
        case .whisperTiny, .whisperBase, .whisperSmall:
            return ["en", "zh", "de", "es", "ru", "ko", "fr", "ja", "pt", "tr", "pl", "ca", "nl", "ar", "sv", "it", "id", "hi", "fi", "vi", "he", "uk", "el", "ms", "cs", "ro", "da", "hu", "ta", "no", "th", "ur", "hr", "bg", "lt", "la", "mi", "ml", "cy", "sk", "te", "fa", "lv", "bn", "sr", "az", "sl", "kn", "et", "mk", "br", "eu", "is", "hy", "ne", "mn", "bs", "kk", "sq", "sw", "gl", "mr", "pa", "si", "km", "sn", "yo", "so", "af", "oc", "ka", "be", "tg", "sd", "gu", "am", "yi", "lo", "uz", "fo", "ht", "ps", "tk", "nn", "mt", "sa", "lb", "my", "bo", "tl", "mg", "as", "tt", "haw", "ln", "ha", "ba", "jw", "su"]
        }
    }
    
    var downloadURL: URL? {
        switch self {
        case .sensevoiceInt8:
            return URL(string: "https://dl.plaid.oo.sb/models/sensevoice-int8.tar.gz")
        case .sensevoiceFp32:
            return URL(string: "https://dl.plaid.oo.sb/models/sensevoice-fp32.tar.gz")
        case .whisperTiny:
            return URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2")
        case .whisperBase:
            return URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.tar.bz2")
        case .whisperSmall:
            return URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2")
        }
    }
    
    var archiveFormat: String {
        switch self {
        case .sensevoiceInt8, .sensevoiceFp32:
            return "tar.gz"
        case .whisperTiny, .whisperBase, .whisperSmall:
            return "tar.bz2"
        }
    }
    
    var extractedDirName: String {
        switch self {
        case .sensevoiceInt8:
            return "sensevoice-int8"
        case .sensevoiceFp32:
            return "sensevoice-fp32"
        case .whisperTiny:
            return "sherpa-onnx-whisper-tiny"
        case .whisperBase:
            return "sherpa-onnx-whisper-base"
        case .whisperSmall:
            return "sherpa-onnx-whisper-small"
        }
    }
    
    // Model file name within the directory
    var modelFileName: String {
        switch self {
        case .sensevoiceInt8:
            return "model.int8.onnx"
        case .sensevoiceFp32:
            return "model.onnx"
        case .whisperTiny, .whisperBase, .whisperSmall:
            return "tiny-encoder.onnx"  // Whisper has encoder/decoder
        }
    }
    
    var tokensFileName: String {
        return "tokens.txt"
    }
}

// MARK: - Model Manager

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var downloadProgress: [LocalModel: Double] = [:]
    @Published var downloadingModels: Set<LocalModel> = []
    @Published var selectedModel: LocalModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedLocalModel")
        }
    }
    
    private let fileManager = FileManager.default
    private var downloadTasks: [LocalModel: URLSessionDownloadTask] = [:]
    
    private init() {
        let savedModel = UserDefaults.standard.string(forKey: "selectedLocalModel") ?? LocalModel.sensevoiceInt8.rawValue
        self.selectedModel = LocalModel(rawValue: savedModel) ?? .sensevoiceInt8
    }
    
    // MARK: - Paths
    
    nonisolated var modelsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Plaid/Models", isDirectory: true)
        
        // Create if doesn't exist
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        return modelsDir
    }
    
    nonisolated func modelPath(_ model: LocalModel) -> URL? {
        let downloadedPath = modelsDirectory.appendingPathComponent(model.extractedDirName)
        if fileManager.fileExists(atPath: downloadedPath.path) {
            return downloadedPath
        }
        return nil
    }
    
    // MARK: - Model Availability
    
    nonisolated func isModelAvailable(_ model: LocalModel) -> Bool {
        guard let path = modelPath(model) else { return false }
        
        // Check if required files exist
        let modelFile = path.appendingPathComponent(model.modelFileName)
        let tokensFile = path.appendingPathComponent(model.tokensFileName)
        
        // For whisper, we need encoder and decoder
        if model.modelType == .whisper {
            let encoderFile = path.appendingPathComponent("\(model.rawValue.replacingOccurrences(of: "whisper-", with: ""))-encoder.onnx")
            let decoderFile = path.appendingPathComponent("\(model.rawValue.replacingOccurrences(of: "whisper-", with: ""))-decoder.onnx")
            return fileManager.fileExists(atPath: encoderFile.path) && 
                   fileManager.fileExists(atPath: decoderFile.path) &&
                   fileManager.fileExists(atPath: tokensFile.path)
        }
        
        return fileManager.fileExists(atPath: modelFile.path) && 
               fileManager.fileExists(atPath: tokensFile.path)
    }
    
    func isModelDownloading(_ model: LocalModel) -> Bool {
        downloadingModels.contains(model)
    }
    
    // MARK: - Download
    
    func downloadModel(_ model: LocalModel) async throws {
        guard let url = model.downloadURL else {
            throw ModelError.noDownloadURL
        }
        
        guard !downloadingModels.contains(model) else {
            throw ModelError.alreadyDownloading
        }
        
        downloadingModels.insert(model)
        downloadProgress[model] = 0
        
        defer {
            downloadingModels.remove(model)
        }
        
        do {
            // Download the archive
            let (tempURL, _) = try await downloadWithProgress(url: url, model: model)
            
            // Extract the archive
            try await extractArchive(at: tempURL, for: model)
            
            // Clean up temp file
            try? fileManager.removeItem(at: tempURL)
            
            downloadProgress[model] = 1.0
            print("Model \(model.displayName) downloaded successfully")
            
        } catch {
            downloadProgress.removeValue(forKey: model)
            throw error
        }
    }
    
    private func downloadWithProgress(url: URL, model: LocalModel) async throws -> (URL, URLResponse) {
        let request = URLRequest(url: url)
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ModelError.downloadFailed
        }
        
        let expectedLength = response.expectedContentLength
        var receivedLength: Int64 = 0
        
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(model.rawValue).\(model.archiveFormat)")
        
        // Remove existing temp file if any
        try? fileManager.removeItem(at: tempURL)
        
        fileManager.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        
        for try await byte in asyncBytes {
            try fileHandle.write(contentsOf: [byte])
            receivedLength += 1
            
            if expectedLength > 0 {
                let progress = Double(receivedLength) / Double(expectedLength)
                await MainActor.run {
                    self.downloadProgress[model] = progress * 0.8  // 80% for download, 20% for extraction
                }
            }
        }
        
        try fileHandle.close()
        
        return (tempURL, response)
    }
    
    private func extractArchive(at archiveURL: URL, for model: LocalModel) async throws {
        let destinationDir = modelsDirectory
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        let tarFlags = model.archiveFormat == "tar.gz" ? "-xzf" : "-xjf"
        process.arguments = [tarFlags, archiveURL.path, "-C", destinationDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ModelError.extractionFailed
        }
        
        await MainActor.run {
            self.downloadProgress[model] = 0.95
        }
    }
    
    // MARK: - Delete
    
    func deleteModel(_ model: LocalModel) throws {
        let downloadedPath = modelsDirectory.appendingPathComponent(model.extractedDirName)
        guard fileManager.fileExists(atPath: downloadedPath.path) else { return }
        
        try fileManager.removeItem(at: downloadedPath)
        
        if selectedModel == model {
            selectedModel = .sensevoiceInt8
        }
    }
    
    func cancelDownload(_ model: LocalModel) {
        downloadTasks[model]?.cancel()
        downloadTasks.removeValue(forKey: model)
        downloadingModels.remove(model)
        downloadProgress.removeValue(forKey: model)
    }
    
    // MARK: - Model Info for sherpa-onnx
    
    struct ModelFiles: Sendable {
        let modelPath: String
        let tokensPath: String
        let modelType: ModelType
        
        let encoderPath: String?
        let decoderPath: String?
    }
    
    nonisolated func getModelFiles(_ model: LocalModel) -> ModelFiles? {
        guard let basePath = modelPath(model) else { return nil }
        
        let tokensPath = basePath.appendingPathComponent(model.tokensFileName).path
        
        switch model.modelType {
        case .sensevoice:
            let modelFile = basePath.appendingPathComponent(model.modelFileName).path
            return ModelFiles(
                modelPath: modelFile,
                tokensPath: tokensPath,
                modelType: .sensevoice,
                encoderPath: nil,
                decoderPath: nil
            )
            
        case .whisper:
            let size = model.rawValue.replacingOccurrences(of: "whisper-", with: "")
            let encoderPath = basePath.appendingPathComponent("\(size)-encoder.onnx").path
            let decoderPath = basePath.appendingPathComponent("\(size)-decoder.onnx").path
            return ModelFiles(
                modelPath: encoderPath,  // Use encoder as main model path
                tokensPath: tokensPath,
                modelType: .whisper,
                encoderPath: encoderPath,
                decoderPath: decoderPath
            )
        }
    }
}

// MARK: - Errors

enum ModelError: Error, LocalizedError {
    case noDownloadURL
    case alreadyDownloading
    case downloadFailed
    case extractionFailed
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .noDownloadURL: return "No download URL available for this model"
        case .alreadyDownloading: return "Model is already being downloaded"
        case .downloadFailed: return "Failed to download model"
        case .extractionFailed: return "Failed to extract model archive"
        case .modelNotFound: return "Model files not found"
        }
    }
}
