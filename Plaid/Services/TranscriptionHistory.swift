import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var timestamp: Date
    var originalText: String
    var correctedText: String?
    var sttProvider: String
    var sttDuration: Double
    var llmDuration: Double?
    var characterCount: Int
    
    init(
        originalText: String,
        correctedText: String? = nil,
        sttProvider: String,
        sttDuration: Double,
        llmDuration: Double? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.originalText = originalText
        self.correctedText = correctedText
        self.sttProvider = sttProvider
        self.sttDuration = sttDuration
        self.llmDuration = llmDuration
        self.characterCount = (correctedText ?? originalText).count
    }
    
    var displayText: String {
        correctedText ?? originalText
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
    
    private init() {
        setupContainer()
        loadRecentRecords()
    }
    
    private func setupContainer() {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            modelContext = modelContainer?.mainContext
        } catch {
            print("Failed to setup SwiftData: \(error)")
        }
    }
    
    func addRecord(
        originalText: String,
        correctedText: String?,
        sttProvider: String,
        sttDuration: Double,
        llmDuration: Double?
    ) {
        guard let context = modelContext else { return }
        
        let record = TranscriptionRecord(
            originalText: originalText,
            correctedText: correctedText,
            sttProvider: sttProvider,
            sttDuration: sttDuration,
            llmDuration: llmDuration
        )
        
        context.insert(record)
        
        do {
            try context.save()
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
    
    var totalCharacters: Int {
        recentRecords.reduce(0) { $0 + $1.characterCount }
    }
}
