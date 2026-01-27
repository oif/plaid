import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var historyService = TranscriptionHistoryService.shared
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showFileImporter = false
    @State private var searchText = ""
    
    var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return historyService.recentRecords
        }
        return historyService.recentRecords.filter {
            $0.displayText.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 500)
        .searchable(text: $searchText, prompt: "Search transcriptions...")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.wav, .audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await appState.processAudioFile(at: url) }
            }
        }
    }
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            statsHeader
            
            Divider()
            
            if filteredRecords.isEmpty {
                emptyStateView
            } else {
                recordsList
            }
        }
        .frame(minWidth: 280)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import Audio", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button {
                    Task { await appState.toggleRecording() }
                } label: {
                    Label(
                        appState.isRecording ? "Stop" : "Record",
                        systemImage: appState.isRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .tint(appState.isRecording ? .red : .accentColor)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
    
    private var statsHeader: some View {
        HStack(spacing: 16) {
            statItem(value: "\(historyService.todayCount)", label: "Today")
            statItem(value: "\(historyService.recentRecords.count)", label: "Total")
            statItem(value: formatCharCount(historyService.totalCharacters), label: "Characters")
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCharCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No Transcriptions Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Press fn + Space anywhere\nto start voice input")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recordsList: some View {
        List(selection: $selectedRecord) {
            ForEach(filteredRecords) { record in
                RecordRow(record: record)
                    .tag(record)
                    .contextMenu {
                        Button {
                            copyToClipboard(record.displayText)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            historyService.deleteRecord(record)
                            if selectedRecord?.id == record.id {
                                selectedRecord = nil
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let record = selectedRecord {
            RecordDetailView(record: record)
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.4))
            
            Text("Select a transcription")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Label("fn + Space", systemImage: "globe")
                Text("Quick voice input anywhere")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct RecordRow: View {
    let record: TranscriptionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.displayText)
                .lineLimit(2)
                .font(.body)
            
            HStack(spacing: 8) {
                Text(record.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .foregroundStyle(.quaternary)
                
                Text(record.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if record.correctedText != nil {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecordDetailView: View {
    let record: TranscriptionRecord
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                if let corrected = record.correctedText, corrected != record.originalText {
                    textSection(title: "Corrected", text: corrected, icon: "sparkles", color: .purple)
                    textSection(title: "Original", text: record.originalText, icon: "text.quote", color: .secondary)
                } else {
                    textSection(title: "Transcription", text: record.originalText, icon: "text.quote", color: .blue)
                }
                
                metadataSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copyToClipboard(record.displayText)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.timestamp, style: .date)
                    .font(.headline)
                Text(record.timestamp, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                statBadge(value: "\(record.characterCount)", label: "chars")
                statBadge(value: record.formattedDuration, label: "time")
            }
        }
    }
    
    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    private func textSection(title: String, text: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    copyToClipboard(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.caption)
            
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                metadataItem(icon: "waveform", label: "Provider", value: record.sttProvider)
                metadataItem(icon: "clock", label: "STT", value: String(format: "%.2fs", record.sttDuration))
                if let llm = record.llmDuration {
                    metadataItem(icon: "sparkles", label: "LLM", value: String(format: "%.2fs", llm))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func metadataItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption)
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
