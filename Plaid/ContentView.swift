import SwiftUI
import UniformTypeIdentifiers

enum MainTab: String, CaseIterable {
    case history = "History"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .history: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .settings: return "slider.horizontal.3"
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case services = "Services"
    case modes = "Modes"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .services: return "bolt.horizontal"
        case .modes: return "square.stack.3d.up"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Custom Tab Switcher

struct TabSwitcher: View {
    @Binding var selectedTab: MainTab
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}

struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRecord: TranscriptionRecord?
    @State private var selectedSettingsSection: SettingsSection = .general
    @State private var showFileImporter = false
    
    @ObservedObject private var historyService = TranscriptionHistoryService.shared
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 500)
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
            // Tab switcher
            TabSwitcher(selectedTab: $appState.selectedMainTab)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            if appState.selectedMainTab == .history {
                historyContent
            } else {
                settingsSidebar
            }
        }
        .frame(minWidth: 280)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.selectedMainTab == .history {
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
    }
    
    private var historyContent: some View {
        VStack(spacing: 0) {
            // Compact stats strip
            statsStrip
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 12)
            
            if historyService.recentRecords.isEmpty {
                emptyStateView
            } else {
                recordsList
            }
        }
    }
    
    private var settingsSidebar: some View {
        List(selection: $selectedSettingsSection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - Stats Strip (Compact)
    
    private var statsStrip: some View {
        HStack(spacing: 0) {
            statsItem(value: historyService.todayCount, label: "Today", icon: "sun.max")
            
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 12)
            
            statsItem(value: historyService.recentRecords.count, label: "Total", icon: "archivebox")
            
            Divider()
                .frame(height: 24)
                .padding(.horizontal, 12)
            
            statsItem(value: formatCharCount(historyService.totalCharacters), label: "Chars", icon: "character.cursor.ibeam")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    private func statsItem(value: Int, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statsItem(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCharCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                // Subtle gradient background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.accentColor.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text("No Transcriptions")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text("Press **fn + Space** anywhere\nto start voice input")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Records List
    
    private var recordsList: some View {
        List(selection: $selectedRecord) {
            ForEach(historyService.recentRecords) { record in
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
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        if appState.selectedMainTab == .settings {
            SettingsContentView(selectedSection: selectedSettingsSection)
                .environmentObject(appState)
        } else if let record = selectedRecord {
            RecordDetailView(record: record)
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 28) {
            ZStack {
                // Multi-layer gradient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.accentColor.opacity(0.12), .purple.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                
                Image(systemName: "waveform.circle")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary.opacity(0.5), .secondary.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Select a Transcription")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                    Text("fn + Space")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Record Row

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

// MARK: - Record Detail View

struct RecordDetailView: View {
    let record: TranscriptionRecord
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                if let corrected = record.correctedText, corrected != record.originalText {
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
                
                metadataSection
            }
            .padding(28)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            // Date/Time with elegant styling
            VStack(alignment: .leading, spacing: 4) {
                Text(record.timestamp, style: .date)
                    .font(.system(size: 18, weight: .semibold))
                Text(record.timestamp, style: .time)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Stats badges
            HStack(spacing: 8) {
                StatBadge(value: "\(record.characterCount)", label: "chars", icon: "character.cursor.ibeam")
                StatBadge(value: record.formattedDuration, label: "duration", icon: "timer")
            }
        }
        .padding(.bottom, 4)
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
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Details")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            HStack(spacing: 16) {
                MetadataChip(icon: "waveform", label: "Provider", value: record.sttProvider)
                MetadataChip(icon: "clock.arrow.circlepath", label: "STT", value: String(format: "%.2fs", record.sttDuration))
                if let llm = record.llmDuration {
                    MetadataChip(icon: "sparkles", label: "LLM", value: String(format: "%.2fs", llm))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Supporting Components

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }
}

struct MetadataChip: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
