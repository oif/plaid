import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var historyService: TranscriptionHistoryService
    @State private var selectedRecord: TranscriptionRecord?
    @State private var selectedSettingsSection: SettingsSection = .general
    @State private var showFileImporter = false
    @State private var emptyStatePulse = false
    @State private var showClearHistoryConfirmation = false
    
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
                        
                        Button {
                            showClearHistoryConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear history")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    recordsList
                }
                .confirmationDialog(
                    "Clear History",
                    isPresented: $showClearHistoryConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear All Records", role: .destructive) {
                        historyService.clearHistory()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will delete all transcription records. Your cumulative statistics (total words, time saved) will be preserved.")
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
        VStack(spacing: PlaidSpacing.sm) {
            HStack {
                Text("TODAY")
                    .font(PlaidTypography.badge)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text(Date(), format: .dateTime.month(.abbreviated).day())
                    .font(PlaidTypography.badge)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
            
            HStack(spacing: PlaidSpacing.md) {
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
                    value: "\(historyService.todayCount)",
                    label: "Sessions",
                    icon: "text.bubble",
                    color: .purple
                )
            }
        }
        .padding(.vertical, PlaidSpacing.md)
        .padding(.horizontal, PlaidSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PlaidRadius.md)
                .fill(.secondary.opacity(statsHovered ? PlaidOpacity.light : PlaidOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.md)
                .strokeBorder(.secondary.opacity(statsHovered ? PlaidOpacity.medium : 0), lineWidth: 1)
        )
        .scaleEffect(statsHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: statsHovered)
        .onHover { hovering in
            statsHovered = hovering
        }
        .help("Click to return to Home")
    }
    
    private func todayStatItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: PlaidSpacing.xs) {
            Image(systemName: icon)
                .font(PlaidTypography.tiny)
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
            .onDisappear {
                emptyStatePulse = false
            }
            
            VStack(spacing: 8) {
                Text("No Transcriptions")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.8))
                
                Text("Press **\(appState.settings.hotkeyDisplayString)** anywhere\nto start voice input")
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
                    
                    if isWide {
                        HStack(alignment: .top, spacing: 16) {
                            WeeklyActivityChart(
                                stats: historyService.weeklyStats,
                                maxWords: historyService.maxDailyWords
                            )
                            .frame(maxWidth: .infinity)
                            
                            AppUsageCard(stats: historyService.appUsageStats)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        WeeklyActivityChart(
                            stats: historyService.weeklyStats,
                            maxWords: historyService.maxDailyWords
                        )
                        
                        AppUsageCard(stats: historyService.appUsageStats)
                    }
                    
                    QuickStartCard(hotkeyParts: appState.settings.hotkeyParts)
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

#Preview {
    ContentView()
        .environmentObject(AppState())
}
