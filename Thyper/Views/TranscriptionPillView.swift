import SwiftUI

struct TranscriptionPillView: View {
    @ObservedObject var pillState: TranscriptionPillState
    
    var body: some View {
        HStack(spacing: 12) {
            if pillState.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white)
                
                Text("Thinking...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                
                    .onAppear {
                        let str = "\(Date()): [UI] Thinking view appeared\n"
                        let url = URL(fileURLWithPath: "/Users/neo/Desktop/thyper_debug.log")
                        if let data = str.data(using: .utf8), let handle = try? FileHandle(forWritingTo: url) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            try? handle.close()
                        }
                    }
            } else {
                Button {
                    pillState.cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(.white.opacity(0.15)))
                
                waveformIndicator
                
                Button {
                    pillState.complete()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(.white))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color.black.opacity(0.85))
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .animation(.easeInOut(duration: 0.2), value: pillState.isProcessing)
    }
    
    private var waveformIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.06), value: pillState.waveformLevels)
            }
        }
        .frame(width: 20, height: 16)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let level = pillState.waveformLevels[safe: index] ?? 0.1
        let centerIndex: CGFloat = 2
        let distance = abs(CGFloat(index) - centerIndex)
        let falloff = 1.0 - (distance / centerIndex) * 0.4
        let effectiveLevel = pillState.isRecording ? CGFloat(level) : 0.15
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 14
        return minHeight + effectiveLevel * falloff * (maxHeight - minHeight)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.5)
        TranscriptionPillView(pillState: TranscriptionPillState())
    }
    .frame(width: 200, height: 100)
}
