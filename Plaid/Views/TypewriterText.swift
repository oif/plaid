import SwiftUI

struct TypewriterText: View {
    let text: String
    let isStreaming: Bool
    let speed: Double
    
    @State private var displayedCount: Int = 0
    @State private var showCursor: Bool = true
    
    init(_ text: String, isStreaming: Bool = false, speed: Double = 0.015) {
        self.text = text
        self.isStreaming = isStreaming
        self.speed = speed
    }
    
    private var displayedText: String {
        if isStreaming {
            let index = text.index(text.startIndex, offsetBy: min(displayedCount, text.count))
            return String(text[..<index])
        }
        return text
    }
    
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(displayedText)
                .font(.body)
                .textSelection(.enabled)
            
            if isStreaming && displayedCount < text.count {
                Text("|")
                    .font(.body)
                    .foregroundStyle(.tint)
                    .opacity(showCursor ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: text) { oldValue, newValue in
            if isStreaming && newValue.count > oldValue.count {
                animateNewCharacters(from: displayedCount, to: newValue.count)
            }
        }
        .onChange(of: isStreaming) { _, streaming in
            if streaming {
                displayedCount = 0
                animateNewCharacters(from: 0, to: text.count)
                startCursorBlink()
            } else {
                displayedCount = text.count
            }
        }
        .onAppear {
            if isStreaming {
                displayedCount = 0
                animateNewCharacters(from: 0, to: text.count)
                startCursorBlink()
            } else {
                displayedCount = text.count
            }
        }
    }
    
    private func animateNewCharacters(from start: Int, to end: Int) {
        guard start < end else { return }
        
        for i in start..<end {
            let delay = Double(i - start) * speed
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if displayedCount < end {
                    displayedCount = i + 1
                }
            }
        }
    }
    
    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !isStreaming || displayedCount >= text.count {
                timer.invalidate()
                showCursor = false
                return
            }
            showCursor.toggle()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TypewriterText("Hello, this is a streaming text example!", isStreaming: true)
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        
        TypewriterText("This is static text.", isStreaming: false)
            .padding()
    }
    .padding()
    .frame(width: 400)
}
