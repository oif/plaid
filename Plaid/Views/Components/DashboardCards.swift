import SwiftUI
import AppKit

// MARK: - Hero Time Saved Card

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
            
            Spacer(minLength: 0)
            
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
                if timeSaved >= 1 {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("That's \(formattedTime) you've gained back")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Start dictating to see time saved")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
        }
        .padding(PlaidSpacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
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
                            colors: [.white.opacity(PlaidOpacity.medium), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .offset(x: 60, y: -40)
                
                RoundedRectangle(cornerRadius: PlaidRadius.xl)
                    .strokeBorder(.white.opacity(PlaidOpacity.light), lineWidth: 1)
            }
        }
        .clipShape(.rect(cornerRadius: PlaidRadius.xl))
        .shadow(color: Color(hue: 0.40, saturation: 0.50, brightness: 0.30).opacity(PlaidOpacity.prominent), radius: isHovered ? 20 : 12, y: isHovered ? 8 : 4)
        .scaleEffect(isHovered ? PlaidHoverScale.default : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Speed Comparison Card

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
                                .fill(.secondary.opacity(PlaidOpacity.medium))
                            
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
                                .fill(.secondary.opacity(PlaidOpacity.medium))
                            
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
        .padding(PlaidSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.secondary.opacity(PlaidOpacity.subtle), in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .strokeBorder(.secondary.opacity(isHovered ? PlaidOpacity.medium : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? PlaidHoverScale.subtle : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
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

// MARK: - Compact Stat Card

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
                        .fill(accentColor.opacity(PlaidOpacity.medium))
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
        .padding(PlaidSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(.secondary.opacity(PlaidOpacity.subtle), in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .strokeBorder(accentColor.opacity(isHovered ? 0.25 : 0), lineWidth: 1)
        )
        .scaleEffect(isHovered ? PlaidHoverScale.emphasis : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Weekly Activity Chart

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
                                .fill(.secondary.opacity(PlaidOpacity.light))
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
        .padding(PlaidSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.secondary.opacity(PlaidOpacity.subtle), in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .strokeBorder(.secondary.opacity(isHovered ? PlaidOpacity.medium : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? PlaidHoverScale.subtle : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(PlaidAnimation.Spring.smooth.delay(0.1)) {
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

// MARK: - Quick Start Card

struct QuickStartCard: View {
    let hotkeyParts: [String]
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.2), .accentColor.opacity(PlaidOpacity.light)],
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
                    ForEach(Array(hotkeyParts.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            Text("+")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        KeyCapView(text: part)
                    }
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
        .padding(PlaidSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .fill(.secondary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: PlaidRadius.lg)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.secondary.opacity(0.12), .secondary.opacity(PlaidOpacity.subtle)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .scaleEffect(isHovered ? PlaidHoverScale.default : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Key Cap View

struct KeyCapView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.primary.opacity(PlaidOpacity.heavy))
            .padding(.horizontal, PlaidSpacing.sm)
            .padding(.vertical, PlaidSpacing.xs)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.secondary.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.secondary.opacity(PlaidOpacity.medium), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            }
    }
}

// MARK: - Performance Card

struct PerformanceCard: View {
    let stats: TranscriptionHistoryService.PerformanceStats
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: PlaidSpacing.lg) {
            HStack {
                Text("Performance")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if stats.totalSessions > 0 {
                    Text("avg of \(stats.totalSessions) sessions")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            if stats.totalSessions == 0 {
                emptyState
            } else {
                VStack(spacing: PlaidSpacing.md) {
                    if let cloud = stats.avgCloudLatency {
                        metricRow(
                            label: "Cloud Latency",
                            value: formatLatency(cloud),
                            detail: "Plaid Cloud 端到端耗时",
                            color: cloud < 2 ? .green : cloud < 5 ? .orange : .red
                        )
                    }
                    
                    if let rtf = stats.realtimeFactor {
                        metricRow(
                            label: "Realtime Factor",
                            value: String(format: "%.1fx", rtf),
                            detail: "录音时长 ÷ STT 处理时长",
                            color: rtf >= 5 ? .green : rtf >= 2 ? .orange : .red
                        )
                    }
                    
                    if stats.avgSTTLatency > 0 {
                        metricRow(
                            label: "STT Latency",
                            value: formatLatency(stats.avgSTTLatency),
                            detail: "语音识别平均耗时",
                            color: stats.avgSTTLatency < 1 ? .green : stats.avgSTTLatency < 3 ? .orange : .red
                        )
                    }
                    
                    if let llm = stats.avgLLMLatency {
                        metricRow(
                            label: "LLM Latency",
                            value: formatLatency(llm),
                            detail: "LLM 修正平均耗时",
                            color: llm < 1 ? .green : llm < 3 ? .orange : .red
                        )
                    }
                    
                    metricRow(
                        label: "Total Latency",
                        value: formatLatency(stats.avgTotalLatency),
                        detail: "端到端平均延迟",
                        color: stats.avgTotalLatency < 2 ? .green : stats.avgTotalLatency < 5 ? .orange : .red
                    )
                    
                    correctionRateRow
                }
            }
        }
        .padding(PlaidSpacing.lg)
        .background(.secondary.opacity(PlaidOpacity.subtle), in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .strokeBorder(.secondary.opacity(isHovered ? PlaidOpacity.medium : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? PlaidHoverScale.subtle : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: PlaidSpacing.sm) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("Performance data will appear here")
                    .font(PlaidTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, PlaidSpacing.lg)
            Spacer()
        }
    }
    
    private func metricRow(label: String, value: String, detail: String, color: Color) -> some View {
        HStack(spacing: PlaidSpacing.md) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                Text(detail)
                    .font(PlaidTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
    
    private var correctionRateRow: some View {
        HStack(spacing: PlaidSpacing.md) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("LLM Correction")
                    .font(.system(size: 11, weight: .medium))
                Text("经过 LLM 修正的比例")
                    .font(PlaidTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            HStack(spacing: PlaidSpacing.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(PlaidOpacity.light))
                        Capsule()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: max(0, geo.size.width * stats.llmCorrectionRate))
                    }
                }
                .frame(width: 48, height: 6)
                
                Text("\(Int(stats.llmCorrectionRate * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private func formatLatency(_ seconds: Double) -> String {
        if seconds < 0.01 { return "-" }
        if seconds < 1 { return String(format: "%.0fms", seconds * 1000) }
        return String(format: "%.2fs", seconds)
    }
}

// MARK: - App Usage Card

struct AppUsageCard: View {
    let stats: [TranscriptionHistoryService.AppUsageStat]
    @State private var isHovered = false
    
    private var displayStats: [TranscriptionHistoryService.AppUsageStat] {
        Array(stats.prefix(5))
    }
    
    private var maxWords: Int {
        displayStats.first?.words ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: PlaidSpacing.lg) {
            HStack {
                Text("App Usage")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(stats.count) apps")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            if stats.isEmpty {
                emptyState
            } else {
                VStack(spacing: PlaidSpacing.sm) {
                    ForEach(displayStats) { stat in
                        appRow(stat)
                    }
                }
            }
        }
        .padding(PlaidSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.secondary.opacity(PlaidOpacity.subtle), in: RoundedRectangle(cornerRadius: PlaidRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: PlaidRadius.lg)
                .strokeBorder(.secondary.opacity(isHovered ? PlaidOpacity.medium : 0.08), lineWidth: 1)
        )
        .scaleEffect(isHovered ? PlaidHoverScale.subtle : 1.0)
        .animation(PlaidAnimation.Spring.default, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: PlaidSpacing.sm) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("Usage by app will appear here")
                    .font(PlaidTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, PlaidSpacing.lg)
            Spacer()
        }
    }
    
    private func appRow(_ stat: TranscriptionHistoryService.AppUsageStat) -> some View {
        HStack(spacing: PlaidSpacing.sm) {
            Group {
                if let icon = stat.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.secondary.opacity(PlaidOpacity.subtle))
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            
            Text(stat.appName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(PlaidOpacity.light))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth(for: stat, in: geo.size.width))
                }
            }
            .frame(height: 6)
            
            Text("\(stat.words)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .trailing)
        }
    }
    
    private func barWidth(for stat: TranscriptionHistoryService.AppUsageStat, in totalWidth: CGFloat) -> CGFloat {
        guard maxWords > 0 else { return 0 }
        let ratio = CGFloat(stat.words) / CGFloat(maxWords)
        return max(4, ratio * totalWidth)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(PlaidTypography.badge)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(PlaidTypography.tiny)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, PlaidSpacing.md)
        .padding(.vertical, PlaidSpacing.sm)
        .glassBackground(in: RoundedRectangle(cornerRadius: 10))
    }
}
