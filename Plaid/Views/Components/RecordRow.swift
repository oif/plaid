import SwiftUI

struct RecordRow: View {
    let record: TranscriptionRecord
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main text with subtle gradient highlight on hover
            Text(record.displayText)
                .lineLimit(2)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(isHovered ? 1 : 0.9))
            
            // Metadata row
            HStack(spacing: 6) {
                // Time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(record.formattedTimestamp)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                
                Text("·")
                    .foregroundStyle(.quaternary)
                    .font(.system(size: 8))
                
                // Duration
                Text(record.formattedDuration)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // AI enhanced indicator
                if record.correctedText != nil {
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
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
