import SwiftUI
import UniformTypeIdentifiers

enum MainTab: String, CaseIterable {
    case home = "Home"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .settings: return "slider.horizontal.3"
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case speech = "Speech"
    case integrations = "Integrations"
    case diagnostics = "Diagnostics"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .speech: return "waveform"
        case .integrations: return "puzzlepiece.extension"
        case .diagnostics: return "stethoscope"
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
        .glassBackground(in: Capsule())
    }
}

struct TabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                    .symbolEffect(.bounce, value: isSelected)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .primary : (isHovered ? .primary.opacity(0.8) : .secondary))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                } else if isHovered {
                    Capsule()
                        .fill(.secondary.opacity(0.08))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRecord: TranscriptionRecord?
    @State private var selectedSettingsSection: SettingsSection = .general
    @State private var showFileImporter = false
    @State private var emptyStatePulse = false
    
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
            
            if appState.selectedMainTab == .home {
                historyContent
            } else {
                settingsSidebar
            }
        }
        .frame(minWidth: 280)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if appState.selectedMainTab == .home {
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
            Button {
                selectedRecord = nil
            } label: {
                statsStrip
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            if historyService.recentRecords.isEmpty {
                emptyStateView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("RECENT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .tracking(0.5)
                        Spacer()
                        Text("\(historyService.recentRecords.count)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    recordsList
                }
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
    
    // MARK: - Stats Strip
    
    @State private var statsHovered = false
    
    private var statsStrip: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text(Date(), format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
            
            // Stats Grid
            HStack(spacing: 12) {
                todayStatItem(
                    value: historyService.todayWPM > 0 ? "\(Int(historyService.todayWPM))" : "-",
                    label: "WPM",
                    icon: "waveform",
                    color: .orange
                )
                
                todayStatItem(
                    value: formatWordCount(historyService.todayWords),
                    label: "Words",
                    icon: "character.cursor.ibeam",
                    color: .blue
                )
                
                todayStatItem(
                    value: formatUsageTime(historyService.todayUsageSeconds),
                    label: "Usage",
                    icon: "clock",
                    color: .green
                )
                
                todayStatItem(
                    value: "#--",
                    label: "Rank",
                    icon: "globe",
                    color: .purple
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.secondary.opacity(statsHovered ? 0.1 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.secondary.opacity(statsHovered ? 0.15 : 0), lineWidth: 1)
        )
        .scaleEffect(statsHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: statsHovered)
        .onHover { hovering in
            statsHovered = hovering
        }
        .help("Click to return to Home")
    }
    
    private func todayStatItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
            
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatUsageTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return seconds > 0 ? "\(Int(seconds))s" : "-"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
    
    private func formatTimeSaved(_ minutes: Double) -> String {
        if minutes < 1 {
            return "<1m"
        } else if minutes < 60 {
            return String(format: "%.0fm", minutes)
        } else {
            let hours = minutes / 60
            return String(format: "%.1fh", hours)
        }
    }
    
    private func formatSpeedMultiplier(_ multiplier: Double) -> String {
        if multiplier < 0.1 { return "-" }
        return String(format: "%.1fx", multiplier)
    }
    
    private func formatWordCount(_ count: Int) -> String {
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
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.accentColor.opacity(emptyStatePulse ? 0.2 : 0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .scaleEffect(emptyStatePulse ? 1.1 : 1.0)
                
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .symbolEffect(.pulse, options: .repeating)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    emptyStatePulse = true
                }
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
            ForEach(Array(historyService.recentRecords.enumerated()), id: \.element.id) { index, record in
                RecordRow(record: record)
                    .tag(record)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
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
        Group {
            if appState.selectedMainTab == .settings {
                SettingsContentView(selectedSection: selectedSettingsSection)
                    .environmentObject(appState)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if let record = selectedRecord {
                RecordDetailView(record: record)
                    .id(record.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else {
                placeholderView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.selectedMainTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedRecord?.id)
    }
    
    private var placeholderView: some View {
        homeOverviewView
    }
    
    private var homeOverviewView: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 700
            
            ScrollView {
                VStack(spacing: 20) {
                    if isWide {
                        HStack(alignment: .top, spacing: 20) {
                            HeroTimeSavedCard(
                                timeSaved: historyService.timeSavedMinutes,
                                formattedTime: formatTimeSaved(historyService.timeSavedMinutes)
                            )
                            .frame(maxWidth: .infinity)
                            
                            SpeedComparisonCard(
                                voiceWPM: historyService.voiceWPM,
                                typingWPM: TranscriptionHistoryService.typingWPM,
                                speedMultiplier: historyService.averageSpeedMultiplier,
                                formattedSpeed: formatSpeedMultiplier(historyService.averageSpeedMultiplier)
                            )
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        HeroTimeSavedCard(
                            timeSaved: historyService.timeSavedMinutes,
                            formattedTime: formatTimeSaved(historyService.timeSavedMinutes)
                        )
                        
                        SpeedComparisonCard(
                            voiceWPM: historyService.voiceWPM,
                            typingWPM: TranscriptionHistoryService.typingWPM,
                            speedMultiplier: historyService.averageSpeedMultiplier,
                            formattedSpeed: formatSpeedMultiplier(historyService.averageSpeedMultiplier)
                        )
                    }
                    
                    HStack(spacing: 16) {
                        CompactStatCard(
                            title: "Total Words",
                            value: formatWordCount(historyService.totalWords),
                            icon: "text.word.spacing",
                            accentColor: .purple
                        )
                        
                        CompactStatCard(
                            title: "Today",
                            value: "\(historyService.todayCount)",
                            subtitle: historyService.todayWords > 0 ? "\(formatWordCount(historyService.todayWords)) words" : nil,
                            icon: "sun.max.fill",
                            accentColor: .orange
                        )
                    }
                    
                    WeeklyActivityChart(
                        stats: historyService.weeklyStats,
                        maxWords: historyService.maxDailyWords
                    )
                    
                    QuickStartCard()
                }
                .padding(24)
                .frame(maxWidth: .infinity)
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
                
                performanceSection
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
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERFORMANCE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
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
        .glassBackground(in: RoundedRectangle(cornerRadius: 10))
    }
}

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

struct HeroTimeSavedCard: View {
    let timeSaved: Double
    let formattedTime: String
    @State private var isHovered = false
    
    private var heroValue: String {
        if timeSaved < 1 {
            return "0"
        } else if timeSaved < 60 {
            return String(format: "%.0f", timeSaved)
        } else {
            return String(format: "%.1f", timeSaved / 60)
        }
    }
    
    private var heroUnit: String {
        if timeSaved < 60 {
            return timeSaved == 1 ? "minute" : "minutes"
        } else {
            let hours = timeSaved / 60
            return hours == 1 ? "hour" : "hours"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME SAVED")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("by using voice instead of typing")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(heroValue)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                
                Text(heroUnit)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                
                Spacer()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("That's \(formattedTime) you've gained back")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
        .padding(20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: 0.38, saturation: 0.65, brightness: 0.55),
                        Color(hue: 0.45, saturation: 0.70, brightness: 0.40)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.15), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .offset(x: 60, y: -40)
                
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Color(hue: 0.40, saturation: 0.50, brightness: 0.30).opacity(0.3), radius: isHovered ? 20 : 12, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SpeedComparisonCard: View {
    let voiceWPM: Double
    let typingWPM: Double
    let speedMultiplier: Double
    let formattedSpeed: String
    @State private var isHovered = false
    @State private var animateProgress = false
    
    private var typingProgress: Double {
        min(typingWPM / max(voiceWPM, 1), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INPUT SPEED")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Text("Words per minute (WPM)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                
                if speedMultiplier > 0 {
                    HStack(spacing: 4) {
                        Text(formattedSpeed)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .monospacedDigit()
                            .foregroundStyle(speedMultiplier >= 2.0 ? Color.orange : .primary)
                        Text("faster")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    
                    Text("Voice")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 45, alignment: .leading)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.secondary.opacity(0.15))
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .orange.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: animateProgress ? geo.size.width : 0)
                        }
                    }
                    .frame(height: 8)
                    
                    Text(voiceWPM > 0 ? "\(Int(voiceWPM))" : "-")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    Text("Typing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .leading)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.secondary.opacity(0.15))
                            
                            Capsule()
                                .fill(.secondary.opacity(0.4))
                                .frame(width: animateProgress ? geo.size.width * typingProgress : 0)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(Int(typingWPM))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
            
            Text("Typing baseline: average 40 WPM")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.secondary.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor)
                }
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accentColor.opacity(isHovered ? 0.25 : 0), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WeeklyActivityChart: View {
    let stats: [TranscriptionHistoryService.DailyStats]
    let maxWords: Int
    @State private var animateBars = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(stats.reduce(0) { $0 + $1.words }) words")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.secondary.opacity(0.1))
                                .frame(height: 80)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    day.isToday
                                        ? LinearGradient(colors: [.accentColor, .accentColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [.secondary.opacity(0.4), .secondary.opacity(0.25)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(height: animateBars ? barHeight(for: day) : 0)
                        }
                        .frame(height: 80)
                        
                        Text(day.dayLabel)
                            .font(.system(size: 9, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(day.isToday ? .primary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 16) {
                legendItem(color: .accentColor, label: "Today")
                legendItem(color: .secondary.opacity(0.4), label: "This week")
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.secondary.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateBars = true
            }
        }
    }
    
    private func barHeight(for day: TranscriptionHistoryService.DailyStats) -> CGFloat {
        guard maxWords > 0 else { return 4 }
        let ratio = CGFloat(day.words) / CGFloat(maxWords)
        return max(4, ratio * 80)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

struct QuickStartCard: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.2), .accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Start Dictating")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    KeyCapView(text: "fn")
                    Text("+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                    KeyCapView(text: "Space")
                    Text("anywhere")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary.opacity(0.4))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.secondary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.secondary.opacity(0.12), .secondary.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct KeyCapView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.primary.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.secondary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.secondary.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
