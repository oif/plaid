import SwiftUI

struct RecordDetailView: View {
    let record: TranscriptionRecord
    
    private var sttProviderEnum: STTProvider? {
        STTProvider(rawValue: record.sttProvider.lowercased())
    }
    
    private var isLocalMode: Bool {
        sttProviderEnum?.isLocal ?? false
    }
    
    private var providerDisplayName: String {
        sttProviderEnum?.displayName ?? record.sttProvider.capitalized
    }
    
    private var providerIcon: String {
        sttProviderEnum?.icon ?? "waveform"
    }
    
    private var recordWPM: Double {
        let totalDuration = record.sttDuration + (record.llmDuration ?? 0)
        guard totalDuration > 0.5 else { return 0 }
        return Double(record.wordCount) / (totalDuration / 60.0)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                if record.isFailed {
                    errorSection
                } else if let corrected = record.correctedText, corrected != record.originalText {
                    textSection(
                        title: "Enhanced",
                        text: corrected,
                        icon: "sparkles",
                        accentColor: .purple,
                        isPrimary: true
                    )
                    textSection(
                        title: "Original",
                        text: record.originalText,
                        icon: "text.quote",
                        accentColor: .secondary,
                        isPrimary: false
                    )
                } else {
                    textSection(
                        title: "Transcription",
                        text: record.originalText,
                        icon: "text.alignleft",
                        accentColor: .accentColor,
                        isPrimary: true
                    )
                }
                
                if !record.isFailed {
                    performanceSection
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !record.isFailed {
                    Button {
                        copyToClipboard(record.displayText)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.timestamp, style: .date)
                        .font(.system(size: 18, weight: .semibold))
                    Text(record.timestamp, style: .time)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: isLocalMode ? "desktopcomputer" : "cloud")
                        .font(.system(size: 10))
                    Text(isLocalMode ? "Local" : "Cloud")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isLocalMode ? .green : .blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    (isLocalMode ? Color.green : Color.blue).opacity(0.12),
                    in: Capsule()
                )
            }
            
            if let appName = record.appName {
                HStack(spacing: 8) {
                    if let icon = record.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(appName)
                        .font(.system(size: 12, weight: .medium))
                    if let bundleId = record.bundleId {
                        Text(bundleId)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                DetailStatPill(value: "\(record.wordCount)", label: "words", icon: "text.word.spacing")
                DetailStatPill(value: "\(record.characterCount)", label: "chars", icon: "character.cursor.ibeam")
                if recordWPM > 0 {
                    DetailStatPill(value: "\(Int(recordWPM))", label: "WPM", icon: "bolt.fill", highlight: recordWPM > 100)
                }
            }
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                
                Text("Transcription Failed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            Text(record.errorMessage ?? "Unknown error")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: providerIcon)
                        .font(.system(size: 10))
                    Text(providerDisplayName)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                
                if let recDur = record.recordingDuration, recDur > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "mic")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fs recorded", recDur))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.red.opacity(0.12), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Text Section
    
    private func textSection(title: String, text: String, icon: String, accentColor: Color, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accentColor)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPrimary ? .primary : .secondary)
                
                Spacer()
                
                Button {
                    copyToClipboard(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            
            // Text content
            Text(text)
                .font(.system(size: isPrimary ? 15 : 13))
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(accentColor.opacity(isPrimary ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accentColor.opacity(isPrimary ? 0.1 : 0.05), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Performance Section
    
    private var isCloudProvider: Bool {
        sttProviderEnum == .plaidCloud
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERFORMANCE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                if isCloudProvider {
                    performanceRow(
                        icon: "bolt.fill",
                        label: "Plaid Cloud",
                        value: "STT + LLM",
                        timing: record.formattedDuration,
                        color: .blue
                    )
                } else {
                    performanceRow(
                        icon: providerIcon,
                        label: "Speech Recognition",
                        value: providerDisplayName,
                        timing: String(format: "%.2fs", record.sttDuration),
                        color: .orange
                    )
                    
                    if let llm = record.llmDuration {
                        Divider()
                            .padding(.leading, 36)
                        
                        performanceRow(
                            icon: "sparkles",
                            label: "LLM Enhancement",
                            value: "Enabled",
                            timing: String(format: "%.2fs", llm),
                            color: .purple
                        )
                    }
                    
                    Divider()
                        .padding(.leading, 36)
                    
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        Text("Total Processing")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(record.formattedDuration)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
            }
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func performanceRow(icon: String, label: String, value: String, timing: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(timing)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Detail Stat Pill

struct DetailStatPill: View {
    let value: String
    let label: String
    let icon: String
    var highlight: Bool = false
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(highlight ? .orange : .secondary)
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? .orange : .primary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.08), in: Capsule())
    }
}
