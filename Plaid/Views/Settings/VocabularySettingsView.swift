import SwiftUI

struct VocabularySettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var newWord = ""
    @State private var searchText = ""
    
    private var filteredVocabulary: [String] {
        if searchText.isEmpty {
            return settings.customVocabulary
        }
        return settings.customVocabulary.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            addBar
            
            Divider()
            
            if settings.customVocabulary.isEmpty {
                emptyState
            } else {
                wordList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Vocabulary")
                .font(.system(size: 16, weight: .semibold))
            Text("词表中的术语会注入到 LLM 修正提示词中，确保拼写一致。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    private var addBar: some View {
        HStack(spacing: 8) {
            TextField("Add word or phrase…", text: $newWord)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addWord() }
            
            Button(action: addWord) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .foregroundStyle(newWord.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
            .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No words yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Add frequently used terms, brand names, or jargon.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var wordList: some View {
        VStack(spacing: 0) {
            if settings.customVocabulary.count > 10 {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.04))
                
                Divider()
            }
            
            List {
                ForEach(filteredVocabulary, id: \.self) { word in
                    HStack {
                        Text(word)
                            .font(.system(size: 13))
                        Spacer()
                        Button {
                            withAnimation {
                                settings.customVocabulary.removeAll { $0 == word }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(0.6)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    let words = filteredVocabulary
                    for index in indexSet {
                        settings.customVocabulary.removeAll { $0 == words[index] }
                    }
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            HStack {
                Text("\(settings.customVocabulary.count) words")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !settings.customVocabulary.isEmpty {
                    Button("Clear All") {
                        settings.customVocabulary.removeAll()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.7))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !settings.customVocabulary.contains(trimmed) else {
            newWord = ""
            return
        }
        withAnimation {
            settings.customVocabulary.append(trimmed)
        }
        newWord = ""
    }
}

#Preview {
    VocabularySettingsView()
        .environmentObject(AppSettings.shared)
        .frame(width: 400, height: 500)
}
