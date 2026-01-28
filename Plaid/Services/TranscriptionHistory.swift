import Foundation
import SwiftData
import AppKit

@Model
final class CumulativeStats {
    var totalWords: Int
    var totalSessions: Int
    var totalUsageSeconds: Double
    var lastUpdated: Date
    
    init() {
        self.totalWords = 0
        self.totalSessions = 0
        self.totalUsageSeconds = 0
        self.lastUpdated = Date()
    }
}

@Model
final class TranscriptionRecord {
    var id: UUID
    var timestamp: Date
    var originalText: String
    var correctedText: String?
    var sttProvider: String
    var sttDuration: Double
    var llmDuration: Double?
    var recordingDuration: Double?
    var characterCount: Int
    var appName: String?
    var bundleId: String?
    
    init(
        originalText: String,
        correctedText: String? = nil,
        sttProvider: String,
        sttDuration: Double,
        llmDuration: Double? = nil,
        recordingDuration: Double? = nil,
        appName: String? = nil,
        bundleId: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.originalText = originalText
        self.correctedText = correctedText
        self.sttProvider = sttProvider
        self.sttDuration = sttDuration
        self.llmDuration = llmDuration
        self.recordingDuration = recordingDuration
        self.characterCount = (correctedText ?? originalText).count
        self.appName = appName
        self.bundleId = bundleId
    }
    
    var displayText: String {
        correctedText ?? originalText
    }
    
    var wordCount: Int {
        let text = displayText
        guard !text.isEmpty else { return 0 }
        
        var count = 0
        var inLatinWord = false
        
        for scalar in text.unicodeScalars {
            let isCJK = (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||
                        (scalar.value >= 0x3400 && scalar.value <= 0x4DBF) ||
                        (scalar.value >= 0x3000 && scalar.value <= 0x303F)
            let isLatin = scalar.properties.isAlphabetic && !isCJK
            let isWhitespace = scalar.properties.isWhitespace
            
            if isCJK {
                if inLatinWord {
                    count += 1
                    inLatinWord = false
                }
                count += 1
            } else if isLatin {
                if !inLatinWord {
                    inLatinWord = true
                }
            } else if isWhitespace || CharacterSet.punctuationCharacters.contains(scalar) {
                if inLatinWord {
                    count += 1
                    inLatinWord = false
                }
            }
        }
        
        if inLatinWord {
            count += 1
        }
        
        return max(count, 1)
    }
    
    var appIcon: NSImage? {
        guard let bundleId else { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var formattedDuration: String {
        let total = sttDuration + (llmDuration ?? 0)
        return String(format: "%.1fs", total)
    }
}

@MainActor
class TranscriptionHistoryService: ObservableObject {
    static let shared = TranscriptionHistoryService()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    @Published var recentRecords: [TranscriptionRecord] = []
    @Published private(set) var cumulativeStats: CumulativeStats?
    
    private init() {
        setupContainer()
        loadRecentRecords()
        loadCumulativeStats()
    }
    
    private func setupContainer() {
        do {
            let schema = Schema([TranscriptionRecord.self, CumulativeStats.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to setup SwiftData: \(error)")
        }
    }
    
    private func loadCumulativeStats() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CumulativeStats>()
        
        do {
            let stats = try context.fetch(descriptor)
            if let existing = stats.first {
                cumulativeStats = existing
            } else {
                let newStats = CumulativeStats()
                context.insert(newStats)
                try context.save()
                cumulativeStats = newStats
            }
        } catch {
            print("Failed to load cumulative stats: \(error)")
        }
    }
    
    private func updateCumulativeStats(words: Int, usageSeconds: Double) {
        guard let stats = cumulativeStats, let context = modelContext else { return }
        
        stats.totalWords += words
        stats.totalSessions += 1
        stats.totalUsageSeconds += usageSeconds
        stats.lastUpdated = Date()
        
        do {
            try context.save()
        } catch {
            print("Failed to update cumulative stats: \(error)")
        }
    }
    
    func addRecord(
        originalText: String,
        correctedText: String?,
        sttProvider: String,
        sttDuration: Double,
        llmDuration: Double?,
        recordingDuration: Double? = nil,
        appName: String? = nil,
        bundleId: String? = nil
    ) {
        guard let context = modelContext else { return }
        
        let record = TranscriptionRecord(
            originalText: originalText,
            correctedText: correctedText,
            sttProvider: sttProvider,
            sttDuration: sttDuration,
            llmDuration: llmDuration,
            recordingDuration: recordingDuration,
            appName: appName,
            bundleId: bundleId
        )
        
        context.insert(record)
        
        do {
            try context.save()
            
            updateCumulativeStats(words: record.wordCount, usageSeconds: sttDuration)
            
            loadRecentRecords()
        } catch {
            print("Failed to save record: \(error)")
        }
    }
    
    func loadRecentRecords(limit: Int = 50) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            var records = try context.fetch(descriptor)
            if records.count > limit {
                records = Array(records.prefix(limit))
            }
            recentRecords = records
        } catch {
            print("Failed to fetch records: \(error)")
        }
    }
    
    func deleteRecord(_ record: TranscriptionRecord) {
        guard let context = modelContext else { return }
        
        context.delete(record)
        
        do {
            try context.save()
            loadRecentRecords()
        } catch {
            print("Failed to delete record: \(error)")
        }
    }
    
    func clearHistory() {
        guard let context = modelContext else { return }
        
        do {
            try context.delete(model: TranscriptionRecord.self)
            try context.save()
            recentRecords = []
        } catch {
            print("Failed to clear history: \(error)")
        }
    }
    
    var todayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return recentRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }.count
    }
    
    var totalWords: Int {
        cumulativeStats?.totalWords ?? recentRecords.reduce(0) { $0 + $1.wordCount }
    }
    
    var totalSessions: Int {
        cumulativeStats?.totalSessions ?? recentRecords.count
    }
    
    var totalUsageSeconds: Double {
        cumulativeStats?.totalUsageSeconds ?? recentRecords.reduce(0.0) { $0 + $1.sttDuration }
    }
    
    var todayWords: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return recentRecords
            .filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.wordCount }
    }
    
    var todayWPM: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayRecords = recentRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        let totalDurationMinutes = todayRecords.reduce(0.0) { $0 + $1.sttDuration } / 60.0
        guard totalDurationMinutes > 0.01 else { return 0 }
        return Double(todayWords) / totalDurationMinutes
    }
    
    var todayUsageSeconds: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return recentRecords
            .filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0.0) { $0 + $1.sttDuration }
    }
    
    var timeSavedMinutes: Double {
        let typingMinutes = Double(totalWords) / Self.typingWPM
        let actualMinutes = totalUsageSeconds / 60.0
        return max(0, typingMinutes - actualMinutes)
    }
    
    static let typingWPM: Double = 40.0
    
    var voiceWPM: Double {
        let sttSeconds = cumulativeStats?.totalUsageSeconds ?? recentRecords.reduce(0.0) { $0 + $1.sttDuration }
        let sttMinutes = sttSeconds / 60.0
        guard sttMinutes > 0.01 else { return 0 }
        return Double(totalWords) / sttMinutes
    }
    
    var averageSpeedMultiplier: Double {
        guard voiceWPM > 0 else { return 0 }
        return voiceWPM / Self.typingWPM
    }
    
    // MARK: - Weekly Stats
    
    struct DailyStats: Identifiable {
        let id = UUID()
        let date: Date
        let words: Int
        let sessions: Int
        let usageSeconds: Double
        
        var dayLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        }
        
        var isToday: Bool {
            Calendar.current.isDateInToday(date)
        }
    }
    
    var weeklyStats: [DailyStats] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).reversed().map { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return DailyStats(date: today, words: 0, sessions: 0, usageSeconds: 0)
            }
            
            let dayRecords = recentRecords.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            let words = dayRecords.reduce(0) { $0 + $1.wordCount }
            let sessions = dayRecords.count
            let usage = dayRecords.reduce(0.0) { $0 + $1.sttDuration }
            
            return DailyStats(date: date, words: words, sessions: sessions, usageSeconds: usage)
        }
    }
    
    var maxDailyWords: Int {
        weeklyStats.map(\.words).max() ?? 1
    }
    
    // MARK: - Per-App Stats
    
    struct AppUsageStat: Identifiable {
        let id: String
        let appName: String
        let bundleId: String?
        let sessions: Int
        let words: Int
        
        var appIcon: NSImage? {
            guard let bundleId else { return nil }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }
    
    var appUsageStats: [AppUsageStat] {
        let grouped = Dictionary(grouping: recentRecords) { $0.bundleId ?? "unknown" }
        
        return grouped.map { bundleId, records in
            let name = records.first(where: { $0.appName != nil })?.appName
                ?? (bundleId == "unknown" ? "Unknown" : bundleId)
            return AppUsageStat(
                id: bundleId,
                appName: name,
                bundleId: bundleId == "unknown" ? nil : bundleId,
                sessions: records.count,
                words: records.reduce(0) { $0 + $1.wordCount }
            )
        }
        .sorted { $0.words > $1.words }
    }
    
    // MARK: - Performance Stats
    
    struct PerformanceStats {
        let avgSTTLatency: Double
        let avgLLMLatency: Double?
        let avgTotalLatency: Double
        let avgCloudLatency: Double?
        let realtimeFactor: Double?
        let llmCorrectionRate: Double
        let totalSessions: Int
    }
    
    private static let cloudProviderValue = "plaid_cloud"
    
    var performanceStats: PerformanceStats {
        let records = recentRecords
        guard !records.isEmpty else {
            return PerformanceStats(
                avgSTTLatency: 0, avgLLMLatency: nil, avgTotalLatency: 0,
                avgCloudLatency: nil, realtimeFactor: nil, llmCorrectionRate: 0, totalSessions: 0
            )
        }
        
        let localRecords = records.filter { $0.sttProvider != Self.cloudProviderValue }
        let cloudRecords = records.filter { $0.sttProvider == Self.cloudProviderValue }
        
        let avgSTT = localRecords.isEmpty ? 0 :
            localRecords.reduce(0.0) { $0 + $1.sttDuration } / Double(localRecords.count)
        
        let llmRecords = localRecords.compactMap { $0.llmDuration }
        let avgLLM: Double? = llmRecords.isEmpty ? nil : llmRecords.reduce(0.0, +) / Double(llmRecords.count)
        
        let avgCloud: Double? = cloudRecords.isEmpty ? nil :
            cloudRecords.reduce(0.0) { $0 + $1.sttDuration } / Double(cloudRecords.count)
        
        let avgTotal = records.reduce(0.0) { $0 + $1.sttDuration + ($1.llmDuration ?? 0) } / Double(records.count)
        
        let rtfRecords = localRecords.compactMap { r -> Double? in
            guard let rec = r.recordingDuration, rec > 0.1 else { return nil }
            return rec / r.sttDuration
        }
        let rtf: Double? = rtfRecords.isEmpty ? nil : rtfRecords.reduce(0.0, +) / Double(rtfRecords.count)
        
        let enhancedCount = llmRecords.count + cloudRecords.filter { $0.correctedText != nil }.count
        let correctionRate = Double(enhancedCount) / Double(records.count)
        
        return PerformanceStats(
            avgSTTLatency: avgSTT,
            avgLLMLatency: avgLLM,
            avgTotalLatency: avgTotal,
            avgCloudLatency: avgCloud,
            realtimeFactor: rtf,
            llmCorrectionRate: correctionRate,
            totalSessions: records.count
        )
    }
}
