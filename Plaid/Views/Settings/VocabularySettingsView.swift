import SwiftUI

struct VocabularySettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var newWord = ""
    @State private var searchText = ""
    @State private var hoveredWord: String?
    @State private var showClearConfirmation = false
    
    private var filteredVocabulary: [String] {
        if searchText.isEmpty {
            return settings.customVocabulary
        }
        return settings.customVocabulary.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var canAdd: Bool {
        !newWord.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: PlaidSpacing.xxl) {
                Spacer(minLength: PlaidSpacing.xl)
                
                header
                addSection
                
                if settings.customVocabulary.isEmpty {
                    emptyState
                } else {
                    wordListSection
                }
                
                Spacer(minLength: PlaidSpacing.xl)
            }
            .padding(.horizontal, PlaidSpacing.xxl)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: PlaidSpacing.sm) {
            Text("Custom Vocabulary")
                .font(PlaidTypography.sectionTitle)
            Text("Terms in this list are injected into the LLM correction prompt to ensure consistent spelling.")
                .font(PlaidTypography.bodySecondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Add Section
    
    private var addSection: some View {
        GlassContainer(spacing: PlaidSpacing.lg) {
            VStack(alignment: .leading, spacing: PlaidSpacing.md) {
                Text("ADD WORD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                
                HStack(spacing: PlaidSpacing.sm) {
                    TextField("Add word or phrase…", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addWord() }
                    
                    Button(action: addWord) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canAdd ? Color.accentColor : Color.secondary.opacity(PlaidOpacity.prominent))
                    .disabled(!canAdd)
                }
            }
            .padding(.vertical, PlaidSpacing.xs)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        GlassContainer(spacing: PlaidSpacing.lg) {
            VStack(spacing: PlaidSpacing.md) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                
                VStack(spacing: PlaidSpacing.xs) {
                    Text("No words yet")
                        .font(PlaidTypography.bodyPrimary)
                        .foregroundStyle(.secondary)
                    Text("Add frequently used terms, brand names, or jargon.")
                        .font(PlaidTypography.bodySecondary)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PlaidSpacing.xxl)
        }
    }
    
    // MARK: - Word List Section
    
    private var wordListSection: some View {
        GlassContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Section header with count badge
                HStack(spacing: PlaidSpacing.sm) {
                    Text("VOCABULARY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    
                    Text("\(settings.customVocabulary.count)")
                        .font(PlaidTypography.badge)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(PlaidOpacity.light), in: Capsule())
                    
                    Spacer()
                    
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Text("Clear All")
                            .font(PlaidTypography.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .alert("Clear All Words?", isPresented: $showClearConfirmation) {
                        Button("Clear All", role: .destructive) {
                            withAnimation {
                                settings.customVocabulary.removeAll()
                                searchText = ""
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove all \(settings.customVocabulary.count) words from your vocabulary. This action cannot be undone.")
                    }
                }
                .padding(.horizontal, PlaidSpacing.lg)
                .padding(.top, PlaidSpacing.lg)
                .padding(.bottom, PlaidSpacing.md)
                
                // Search bar (shown when >10 words)
                if settings.customVocabulary.count > 10 {
                    HStack(spacing: PlaidSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        TextField("Search…", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(PlaidTypography.bodySecondary)
                    }
                    .padding(.horizontal, PlaidSpacing.lg)
                    .padding(.vertical, PlaidSpacing.sm)
                    .background(.secondary.opacity(PlaidOpacity.subtle))
                }
                
                // Word rows
                VStack(spacing: 0) {
                    ForEach(filteredVocabulary, id: \.self) { word in
                        wordRow(word)
                    }
                }
                .padding(.horizontal, PlaidSpacing.sm)
                .padding(.bottom, PlaidSpacing.sm)
                
                // Filtered state hint
                if !searchText.isEmpty {
                    Text("Showing \(filteredVocabulary.count) of \(settings.customVocabulary.count)")
                        .font(PlaidTypography.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, PlaidSpacing.md)
                }
            }
        }
    }
    
    // MARK: - Word Row
    
    private func wordRow(_ word: String) -> some View {
        HStack {
            Text(word)
                .font(PlaidTypography.bodySecondary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    settings.customVocabulary.removeAll { $0 == word }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(PlaidOpacity.prominent))
            }
            .buttonStyle(.plain)
            .opacity(hoveredWord == word ? 1 : 0)
        }
        .padding(.horizontal, PlaidSpacing.md)
        .padding(.vertical, PlaidSpacing.sm + 2)
        .background(
            hoveredWord == word
                ? Color.secondary.opacity(PlaidOpacity.light)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: PlaidRadius.sm)
        )
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredWord = isHovered ? word : nil
            }
        }
    }
    
    // MARK: - Actions
    
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
        .frame(width: 500, height: 600)
}
