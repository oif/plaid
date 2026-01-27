import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var currentTime = Date()
    @State private var showFileImporter = false
    @Namespace private var glassNamespace
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                headerView
                    .padding(.top, 12)
                
                transcriptionArea
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                Spacer()
                
                controlBar
                    .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onReceive(timer) { time in
            if appState.isRecording {
                currentTime = time
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: appState.isRecording)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Thyper")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("AI Voice Dictation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            statusIndicator
        }
        .padding(.horizontal, 24)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            if appState.isRecording {
                TimelineView(.animation(minimumInterval: 1/30)) { _ in
                    AudioWaveformView(level: appState.sttService.audioLevel, samples: appState.sttService.waveformSamples, barCount: 10, spacing: 1, cornerRadius: 0.5)
                        .frame(width: 30, height: 28)
                        .tint(.red)
                }
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)
            }
            
            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: appState.isRecording ? 28 : nil)
        .padding(.horizontal, 12)
        .padding(.vertical, appState.isRecording ? 4 : 8)
        .glassEffect(
            .regular
                .tint(statusColor.opacity(0.15))
                .interactive(),
            in: .capsule
        )
        .glassEffectID("statusIndicator", in: glassNamespace)
    }
    
    private var statusColor: Color {
        if appState.isRecording {
            return .red
        } else if appState.isProcessing {
            return .orange
        } else {
            return .green
        }
    }
    
    private var transcriptionArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if appState.transcribedText.isEmpty && appState.correctedText.isEmpty && !appState.isRecording {
                    emptyStateView
                } else {
                    if !appState.transcribedText.isEmpty {
                        transcriptionCard(
                            title: "Original",
                            text: appState.transcribedText,
                            icon: "text.quote",
                            tintColor: .secondary
                        )
                    }
                    
                    if !appState.correctedText.isEmpty && appState.correctedText != appState.transcribedText {
                        transcriptionCard(
                            title: "Corrected",
                            text: appState.correctedText,
                            icon: "sparkles",
                            tintColor: .green,
                            isStreaming: appState.isProcessing && appState.settings.enableLLMCorrection
                        )
                    }
                    
                    if appState.timing.totalDuration > 0 {
                        timingStatsView
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var liveWaveformCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if appState.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: .red.opacity(0.6), radius: 4)
                    Text("Recording")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "waveform")
                        .foregroundStyle(.blue)
                    Text("Audio")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                Spacer()
                if appState.isRecording {
                    Text(recordingDurationText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(appState.timing.formattedRecording)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            RecordedWaveformView(
                samples: appState.sttService.waveformSamples,
                barWidth: 2,
                barSpacing: 1,
                color: appState.isRecording ? .red : .blue
            )
            .frame(height: 40)
        }
        .padding(14)
        .glassEffect(
            .regular.tint((appState.isRecording ? Color.red : Color.blue).opacity(0.1)),
            in: .rect(cornerRadius: 14)
        )
        .glassEffectID("waveformCard", in: glassNamespace)
        .animation(.easeInOut(duration: 0.2), value: appState.isRecording)
    }
    
    private var recordingDurationText: String {
        let duration = currentTime.timeIntervalSince(appState.recordingStartTime ?? currentTime)
        return String(format: "%.1fs", duration)
    }
    
    private var timingStatsView: some View {
        HStack(spacing: 16) {
            timingItem(icon: "mic.fill", label: "Recording", value: appState.timing.formattedRecording, color: .red)
            timingItem(icon: "waveform", label: "STT", value: appState.timing.formattedSTT, color: .blue)
            if appState.timing.llmDuration > 0 {
                timingItem(icon: "sparkles", label: "LLM", value: appState.timing.formattedLLM, color: .purple)
            }
            if appState.timing.injectDuration > 0 {
                timingItem(icon: "keyboard", label: "Inject", value: appState.timing.formattedInject, color: .orange)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Total: \(appState.timing.formattedTotal)")
                    .fontWeight(.medium)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(
                .regular.tint(.cyan.opacity(0.2)),
                in: .capsule
            )
        }
        .padding(14)
        .glassEffect(
            .regular.tint(.cyan.opacity(0.08)),
            in: .rect(cornerRadius: 14)
        )
        .glassEffectID("timingStats", in: glassNamespace)
    }
    
    private func timingItem(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if appState.isRecording {
                VStack(spacing: 20) {
                    AudioWaveformView(level: appState.sttService.audioLevel, barCount: 7, spacing: 6, cornerRadius: 3)
                        .frame(width: 120, height: 60)
                        .tint(.red)
                    
                    VStack(spacing: 10) {
                        Text("Listening...")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Click stop or press ⌘R when done")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(32)
                .glassEffect(
                    .regular.tint(.red.opacity(0.1)),
                    in: .rect(cornerRadius: 24)
                )
                .glassEffectID("emptyState", in: glassNamespace)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.secondary.opacity(0.6))
                    
                    VStack(spacing: 10) {
                        Text("Ready to Dictate")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("Click the record button or press ⌘R to start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(32)
                .glassEffect(
                    .regular.tint(.accentColor.opacity(0.05)),
                    in: .rect(cornerRadius: 24)
                )
                .glassEffectID("emptyState", in: glassNamespace)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func transcriptionCard(title: String, text: String, icon: String, tintColor: Color, isStreaming: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tintColor)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(tintColor)
                
                if isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                }
                
                Spacer()
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
            }
            
            if isStreaming {
                TypewriterText(text, isStreaming: true)
            } else {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .glassEffect(
            .regular.tint(tintColor.opacity(0.1)),
            in: .rect(cornerRadius: 16)
        )
    }
    
    private var controlBar: some View {
        GlassEffectContainer(spacing: 24) {
            HStack(spacing: 24) {
                recordButton
                    .glassEffectID("recordButton", in: glassNamespace)
                
                importButton
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.isRecording ? "Recording..." : "Press to Record")
                        .font(.headline)
                    
                    Text("⌘R to toggle • ⌘O to import")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                providerBadge
                    .glassEffectID("providerBadge", in: glassNamespace)
            }
            .padding(.horizontal, 24)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.wav, .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await appState.processAudioFile(at: url)
                    }
                }
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }
    
    private var importButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Image(systemName: "doc.badge.plus")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(appState.isRecording || appState.isProcessing)
        .keyboardShortcut("o", modifiers: [.command])
    }
    
    private var recordButton: some View {
        Button {
            Task {
                await appState.toggleRecording()
            }
        } label: {
            Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                .font(.title2)
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(appState.isRecording ? .red : .accentColor)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .keyboardShortcut("r", modifiers: [.command])
    }
    
    private var providerBadge: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: appState.settings.sttProvider.icon)
                        .font(.caption)
                    Text(appState.settings.sttProvider.displayName)
                        .font(.caption)
                    if appState.settings.sttProvider.isLocal {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(
                    .regular
                        .tint(.accentColor.opacity(0.2))
                        .interactive(),
                    in: .capsule
                )
                
                if appState.settings.enableLLMCorrection {
                    HStack(spacing: 5) {
                        Image(systemName: appState.settings.llmProvider.icon)
                        Text(appState.settings.llmProvider.displayName)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(
                        .regular.tint(.purple.opacity(0.15)),
                        in: .capsule
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
