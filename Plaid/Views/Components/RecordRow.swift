import SwiftUI

struct RecordRow: View {
    let record: TranscriptionRecord
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            appIconView
            
            VStack(alignment: .leading, spacing: 6) {
                if record.isFailed {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.8))
                        Text(record.errorMessage ?? "Unknown error")
                            .lineLimit(2)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(isHovered ? 0.9 : 0.7))
                    }
                } else {
                    Text(record.displayText)
                        .lineLimit(2)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(isHovered ? 1 : 0.9))
                }
                
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(record.formattedTimestamp)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    
                    if let recDur = record.recordingDuration, recDur > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                            .font(.system(size: 8))
                        
                        Text(String(format: "%.0fs", recDur))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    if !record.isFailed {
                        Text("·")
                            .foregroundStyle(.quaternary)
                            .font(.system(size: 8))
                        
                        Text(record.formattedDuration)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if record.isFailed {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                            Text("Failed")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.08), in: Capsule())
                    } else if record.correctedText != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("AI")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.purple.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var appIconView: some View {
        Group {
            if let icon = record.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.secondary.opacity(0.08))
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
