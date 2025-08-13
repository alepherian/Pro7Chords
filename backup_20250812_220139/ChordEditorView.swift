import SwiftUI
import Foundation
import UniformTypeIdentifiers
import AppKit

struct ChordEditorView: View {
    // MARK: - State Management
    @StateObject private var fileManager: FileManagerService = FileManagerService()
    @StateObject private var transposer: ChordTransposerService = ChordTransposerService()
    
    @State private var lyrics: String = ""
    @State private var selectedChord: String = "C"
    @State private var errorMessage: String?
    @State private var showingRecentFiles = false
    @State private var showingFileInfo = false
    @State private var fileInfo: ProPresenterFileInfo?
    @State private var cursorPosition: Int = 0
    @State private var transposeSteps: Int = 0
    @State private var detectedKey: String?
    @State private var isTextOnlyMode: Bool = false
    
    // Chord management
    @State private var chordMap: [String: String] = [:]
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []
    
    // Constants
    private static let maxUndoStackSize = 50
    private static let maxUndoStackMemorySize = 1_000_000 // 1MB limit
    
    // Common chords organized by category
    private let commonChords = [
        "Major": ["C", "D", "E", "F", "G", "A", "B"],
        "Minor": ["Cm", "Dm", "Em", "Fm", "Gm", "Am", "Bm"],
        "7th": ["C7", "D7", "E7", "F7", "G7", "A7", "B7"],
        "Extended": ["Cmaj7", "Dm7", "Em7", "Fmaj7", "G7", "Am7", "Bm7b5"]
    ]
    
    // Text-only mode helpers
    private let slideTemplates = [
        "Verse": "=== Verse ===\n\n\n",
        "Chorus": "=== Chorus ===\n\n\n",
        "Bridge": "=== Bridge ===\n\n\n",
        "Intro": "=== Intro ===\n\n\n",
        "Outro": "=== Outro ===\n\n\n"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
            
            // MARK: - Main Content
            HSplitView {
                // Left Panel - Chord Selection
                chordSelectionPanel
                
                // Right Panel - Text Editor
                textEditorPanel
            }
            .frame(minHeight: 400)
            
            // MARK: - Status Bar
            statusBar
        }
        .navigationTitle("ProPresenter 7 Chord Editor")
        .sheet(isPresented: $showingRecentFiles) {
            recentFilesSheet
        }
        .sheet(isPresented: $showingFileInfo) {
            if let info = fileInfo {
                fileInfoSheet(info)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            setupDefaultContent()
            detectKeyFromLyrics()
        }
        .onChange(of: lyrics) { _, newValue in
            saveToUndoStack()
            detectKeyFromLyrics()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // File operations
            HStack(spacing: 8) {
                Button(action: showRecentFiles) {
                    Label("Recent", systemImage: "clock")
                }
                
                Button(action: loadFile) {
                    Label("Open", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(fileManager.currentFileURL == nil)
                
                if fileManager.currentFileURL?.pathExtension.lowercased() == "pro" {
                    Button(action: showFileInfo) {
                        Label("Info", systemImage: "info.circle")
                    }
                    .disabled(isTextOnlyMode)
                    .help(isTextOnlyMode ? "File info not available in text-only mode" : "Show file information")
                }
            }
            
            Spacer()
            
            // Key and transpose controls
            HStack(spacing: 12) {
                if let key = detectedKey {
                    Text("Key: \(key)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Stepper("Transpose: \(transposeSteps)", value: $transposeSteps, in: -11...11)
                    .onChange(of: transposeSteps) { _, newValue in
                        transposeAllChords(by: newValue - (transposer.transposeSteps))
                        transposer.transposeSteps = newValue
                    }
                
                Button("Reset") {
                    transposeSteps = 0
                    transposer.transposeSteps = 0
                }
                .disabled(transposeSteps == 0)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Chord Selection Panel
    private var chordSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chord Library")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(commonChords.keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                                ForEach(commonChords[category] ?? [], id: \.self) { chord in
                                    Button(chord) {
                                        selectedChord = chord
                                        insertChordAtCursor()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundColor(selectedChord == chord ? .white : .primary)
                                    .background(selectedChord == chord ? Color.blue : Color.clear)
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Slide Templates for Text-Only Mode
                    if isTextOnlyMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Templates")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                ForEach(slideTemplates.keys.sorted(), id: \.self) { templateName in
                                    Button(templateName) {
                                        insertSlideTemplate(templateName)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .foregroundColor(.orange)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal)
                            
                            Button("Add Slide Separator") {
                                insertSlideSeparator()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.orange)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Custom chord input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack {
                            TextField("Enter chord", text: $selectedChord)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if isValidChord(selectedChord) {
                                        insertChordAtCursor()
                                    }
                                }
                            
                            Button("Insert") {
                                insertChordAtCursor()
                            }
                            .disabled(!isValidChord(selectedChord))
                        }
                        .padding(.horizontal)
                        
                        if !isValidChord(selectedChord) && !selectedChord.isEmpty {
                            Text("Invalid chord format")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Text Editor Panel
    private var textEditorPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lyrics & Chords")
                    .font(.headline)
                
                Spacer()
                
                // Undo/Redo buttons
                HStack(spacing: 4) {
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(undoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: .command)
                    
                    Button(action: redo) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(redoStack.isEmpty)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                }
            }
            
            // Text editor with chord highlighting
            TextEditor(text: $lyrics)
                .font(.system(.body, design: .monospaced))
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { _ in
                    updateCursorPosition()
                }
        }
        .padding()
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            if fileManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing...")
                        .font(.caption)
                }
            } else if let url = fileManager.currentFileURL {
                HStack(spacing: 8) {
                    Text("File: \(url.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isTextOnlyMode && url.pathExtension.lowercased() == "pro" {
                        Text("(Text-Only Mode)")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
            } else {
                Text("No file loaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Chords: \(countChords())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Position: \(cursorPosition)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Recent Files Sheet
    private var recentFilesSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Files")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    fileManager.clearRecentFiles()
                }
                .foregroundColor(.red)
            }
            
            if fileManager.recentFiles.isEmpty {
                Text("No recent files")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List(fileManager.recentFiles) { file in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.title)
                                .font(.body)
                            Text(file.url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Last opened: \(file.lastOpened, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open") {
                            Task {
                                await handleFileLoad(from: file.url)
                            }
                            showingRecentFiles = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .swipeActions {
                        Button("Remove", role: .destructive) {
                            fileManager.removeRecentFile(file)
                        }
                    }
                }
                .frame(minHeight: 200)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    showingRecentFiles = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    // MARK: - File Info Sheet
    private func fileInfoSheet(_ info: ProPresenterFileInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Information")
                .font(.headline)
            
            Grid(alignment: .leading) {
                GridRow {
                    Text("Filename:")
                        .fontWeight(.medium)
                    Text(info.filename)
                }
                GridRow {
                    Text("Slides:")
                        .fontWeight(.medium)
                    Text("\(info.slideCount)")
                }
                GridRow {
                    Text("Has Chords:")
                        .fontWeight(.medium)
                    Text(info.hasExistingChords ? "Yes" : "No")
                        .foregroundColor(info.hasExistingChords ? .green : .orange)
                }
            }
            
            if !info.textSlides.isEmpty {
                Text("Text Slides:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                List(info.textSlides.prefix(5)) { slide in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slide.previewText)
                            .font(.body)
                        HStack {
                            Text("ID: \(slide.id.prefix(8))...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            if slide.hasChords {
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 150)
                
                if info.textSlides.count > 5 {
                    Text("... and \(info.textSlides.count - 5) more slides")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    showingFileInfo = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    // MARK: - Actions
    private func setupDefaultContent() {
        lyrics = """
        Amazing grace how sweet the sound
        That saved a wretch like me
        I once was lost but now am found
        Was blind but now I see
        """
    }
    
    private func insertChordAtCursor() {
        guard isValidChord(selectedChord) else { return }
        
        saveToUndoStack()
        
        let insertPosition = max(0, min(cursorPosition, lyrics.count))
        let beforeCursor = lyrics.prefix(insertPosition)
        let afterCursor = lyrics.suffix(lyrics.count - insertPosition)
        
        lyrics = String(beforeCursor) + "[\(selectedChord)]" + String(afterCursor)
        cursorPosition = insertPosition + selectedChord.count + 2
    }
    
    private func insertSlideTemplate(_ templateName: String) {
        guard let template = slideTemplates[templateName] else { return }
        
        saveToUndoStack()
        
        let insertPosition = max(0, min(cursorPosition, lyrics.count))
        let beforeCursor = lyrics.prefix(insertPosition)
        let afterCursor = lyrics.suffix(lyrics.count - insertPosition)
        
        lyrics = String(beforeCursor) + "\n\n" + template + String(afterCursor)
        cursorPosition = insertPosition + template.count + 2
    }
    
    private func insertSlideSeparator() {
        saveToUndoStack()
        
        let separator = "\n\n=== Slide ===\n\n\n"
        let insertPosition = max(0, min(cursorPosition, lyrics.count))
        let beforeCursor = lyrics.prefix(insertPosition)
        let afterCursor = lyrics.suffix(lyrics.count - insertPosition)
        
        lyrics = String(beforeCursor) + separator + String(afterCursor)
        cursorPosition = insertPosition + separator.count
    }
    
    private func isValidChord(_ chord: String) -> Bool {
        return Chord(from: chord) != nil
    }
    
    private func saveToUndoStack() {
        undoStack.append(lyrics)
        redoStack.removeAll()
        
        // Improved memory management for undo stack
        cleanupUndoStack()
    }
    
    private func cleanupUndoStack() {
        // Limit by count
        if undoStack.count > Self.maxUndoStackSize {
            undoStack.removeFirst(undoStack.count - Self.maxUndoStackSize)
        }
        
        // Limit by memory usage (approximate)
        let totalMemory = undoStack.reduce(0) { $0 + $1.utf8.count }
        if totalMemory > Self.maxUndoStackMemorySize {
            let targetSize = Self.maxUndoStackMemorySize / 2
            var currentMemory = totalMemory
            var removeCount = 0
            
            for text in undoStack {
                if currentMemory <= targetSize { break }
                currentMemory -= text.utf8.count
                removeCount += 1
            }
            
            if removeCount > 0 {
                undoStack.removeFirst(removeCount)
            }
        }
    }
    
    private func undo() {
        guard !undoStack.isEmpty else { return }
        
        redoStack.append(lyrics)
        lyrics = undoStack.removeLast()
    }
    
    private func redo() {
        guard !redoStack.isEmpty else { return }
        
        undoStack.append(lyrics)
        lyrics = redoStack.removeLast()
    }
    
    private func detectKeyFromLyrics() {
        detectedKey = transposer.detectKey(from: lyrics)
    }
    
    private func transposeAllChords(by steps: Int) {
        guard steps != 0 else { return }
        
        saveToUndoStack()
        lyrics = transposer.transposeText(lyrics, by: steps)
    }
    
    private func countChords() -> Int {
        return StringUtilities.extractChords(from: lyrics).count
    }
    
    private func updateCursorPosition() {
        // This would need to be implemented with NSTextView coordination
        // For now, we'll track it approximately
    }
    
    // MARK: - File Operations
    private func showRecentFiles() {
        showingRecentFiles = true
    }
    
    private func showFileInfo() {
        guard let url = fileManager.currentFileURL else { return }
        
        Task {
            do {
                let parser = ProFileParser()
                fileInfo = try await parser.analyzeProPresenterFile(url)
                showingFileInfo = true
            } catch {
                await handleError(error, context: "analyzing file")
            }
        }
    }
    
    private func loadFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .text,
            .plainText,
            UTType(filenameExtension: "pro") ?? .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Lyrics or ProPresenter File"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await handleFileLoad(from: url)
            }
        }
    }
    
    @MainActor
    private func handleFileLoad(from url: URL) async {
        do {
            lyrics = try await fileManager.loadFile(from: url)
            chordMap = [:] // Reset chord mapping
            errorMessage = nil
            isTextOnlyMode = false // Reset text-only mode
            
            // Analyze ProPresenter file if applicable
            if url.pathExtension.lowercased() == "pro" {
                let parser = ProFileParser()
                do {
                    fileInfo = try await parser.analyzeProPresenterFile(url)
                } catch {
                    AppLogger.warning("ProPresenter analysis failed", error: error)
                    // File loaded in text-only mode, analysis isn't critical
                    isTextOnlyMode = true
                }
            }
            
        } catch {
            await handleError(error, context: "loading file")
            if error.localizedDescription.contains("text-only mode") {
                isTextOnlyMode = true
            }
        }
    }
    
    private func saveFile() {
        guard let originalURL = fileManager.currentFileURL else {
            errorMessage = "No file loaded to save"
            return
        }
        
        let savePanel = NSSavePanel()
        let isProFile = originalURL.pathExtension.lowercased() == "pro"
        let suffix = isProFile ? "_chords.pro" : "_chords.txt"
        
        savePanel.nameFieldStringValue = originalURL.deletingPathExtension().lastPathComponent + suffix
        savePanel.allowedContentTypes = [isProFile ? (UTType(filenameExtension: "pro") ?? .data) : .plainText]
        savePanel.title = isProFile ? "Save ProPresenter File with Chords" : "Save Text File"
        
        if savePanel.runModal() == .OK, let saveURL = savePanel.url {
            Task {
                do {
                    // Extract chords from lyrics for ProPresenter files
                    let chordsToSave = isProFile ? extractChordsFromLyrics() : [:]
                    AppLogger.info("Saving with \(chordsToSave.count) chord mappings")
                    
                    try await fileManager.saveFile(content: lyrics, to: saveURL, chords: chordsToSave)
                    errorMessage = "Saved successfully to \(saveURL.lastPathComponent)"
                } catch {
                    await handleError(error, context: "saving file")
                }
            }
        }
    }
    
    @MainActor
    private func handleError(_ error: Error, context: String) async {
        AppLogger.error("Error \(context)", error: error)
        
        // Handle protobuf errors gracefully
        if error.localizedDescription.contains("BinaryDecodingError") {
            errorMessage = """
            Cannot analyze this ProPresenter file format.
            
            The file structure doesn't match the expected format. This could be due to:
            • Different ProPresenter version
            • Newer file format
            • Compressed or encrypted data
            
            You can still use text-only mode for chord editing.
            """
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    // Extract chords from the current lyrics text and map to slide cues
    private func extractChordsFromLyrics() -> [String: String] {
        var chordMap: [String: String] = [:]
        
        // Split lyrics by slide separators
        let slides = lyrics.components(separatedBy: "--- Next Slide ---")
        
        // Find slides that actually have chords and preserve the full text
        var slideWithChordsIndex = 0
        
        for (index, slideText) in slides.enumerated() {
            let cleanText = slideText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty slides
            if cleanText.isEmpty || cleanText == "--- Next Slide ---" {
                continue
            }
            
            // Check if this slide has chords (ChordPro format)
            if cleanText.contains("[") && cleanText.contains("]") {
                // Store the entire slide text with chords intact
                let slideKey = String(slideWithChordsIndex)
                chordMap[slideKey] = cleanText
                AppLogger.debug("Slide \(index) (lyrics) -> Slide \(slideWithChordsIndex) (ProPresenter): Full ChordPro text")
            }
            
            slideWithChordsIndex += 1
        }
        
        AppLogger.info("Total chord mappings: \(chordMap.count)")
        return chordMap
    }
}

#Preview {
    ChordEditorView()
        .frame(width: 800, height: 600)
}
