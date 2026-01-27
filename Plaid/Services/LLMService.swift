import Foundation

@MainActor
class LLMService {
    
    func process(_ text: String, systemPrompt: String, onPartial: ((String) -> Void)? = nil) async throws -> String {
        let settings = AppSettings.shared
        
        let apiKey = settings.effectiveLLMApiKey
        let endpoint = settings.effectiveLLMEndpoint
        
        guard !apiKey.isEmpty, !endpoint.isEmpty else {
            return text
        }
        
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidEndpoint
        }
        
        return try await executeRequest(
            text: text,
            systemPrompt: systemPrompt,
            url: url,
            apiKey: apiKey,
            model: settings.llmModel,
            onPartial: onPartial
        )
    }
    
    // MARK: - Private
    
    private func executeRequest(
        text: String,
        systemPrompt: String,
        url: URL,
        apiKey: String,
        model: String,
        onPartial: ((String) -> Void)?
    ) async throws -> String {
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        
        let useStreaming = onPartial != nil
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1,
            "max_tokens": 512
        ]
        
        if useStreaming {
            requestBody["stream"] = true
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let requestStart = Date()
        print("🚀 LLM Request: \(model) @ \(url.host ?? "unknown")")
        
        if useStreaming {
            return try await streamingRequest(request: request, onPartial: onPartial!, requestStart: requestStart)
        } else {
            return try await standardRequest(request: request, requestStart: requestStart)
        }
    }
    
    private func standardRequest(request: URLRequest, requestStart: Date) async throws -> String {
        let (data, response) = try await NetworkSession.shared.data(for: request)
        
        let ttfb = Date().timeIntervalSince(requestStart)
        print("⏱️ LLM TTFB: \(String(format: "%.2fs", ttfb))")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError
        }
        
        print("📥 LLM Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ LLM Error: \(message)")
                throw LLMError.serverError(message)
            }
            throw LLMError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }
        
        let totalTime = Date().timeIntervalSince(requestStart)
        print("✅ LLM Complete: \(String(format: "%.2fs", totalTime)) total")
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func streamingRequest(request: URLRequest, onPartial: @escaping (String) -> Void, requestStart: Date) async throws -> String {
        let (bytes, response) = try await NetworkSession.shared.bytes(for: request)
        
        let ttfb = Date().timeIntervalSince(requestStart)
        print("⏱️ LLM TTFB (stream): \(String(format: "%.2fs", ttfb))")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.apiError
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            if let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ LLM Error: \(message)")
                throw LLMError.serverError(message)
            }
            throw LLMError.httpError(httpResponse.statusCode)
        }
        
        var fullContent = ""
        var firstTokenTime: Date?
        
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                
                if jsonStr == "[DONE]" {
                    break
                }
                
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    if firstTokenTime == nil {
                        firstTokenTime = Date()
                        let ttft = firstTokenTime!.timeIntervalSince(requestStart)
                        print("⚡ LLM First Token: \(String(format: "%.2fs", ttft))")
                    }
                    
                    fullContent += content
                    onPartial(fullContent)
                }
            }
        }
        
        let totalTime = Date().timeIntervalSince(requestStart)
        print("✅ LLM Stream Complete: \(String(format: "%.2fs", totalTime)) total, \(fullContent.count) chars")
        
        return fullContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LLMError: Error, LocalizedError {
    case apiError
    case parseError
    case invalidEndpoint
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError: return "API request failed"
        case .parseError: return "Failed to parse response"
        case .invalidEndpoint: return "Invalid API endpoint"
        case .httpError(let code): return "HTTP error: \(code)"
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}
