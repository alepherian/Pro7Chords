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
    @State private var showingChordLibrary = false
    @State private var fileInfo: ProPresenterFileInfo?
    @State private var selectedTextRange: NSRange = NSRange(location: 0, length: 0)
    @State private var pendingSelectedTextRange: NSRange?
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
        .sheet(isPresented: $showingChordLibrary) {
            ChordLibraryManagementView()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            AppLogger.logSystemInfo()
            setupDefaultContent()
            detectKeyFromLyrics()
            setupNotificationListeners()
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
                .buttonStyle(.borderedProminent)
                .help("Open a ProPresenter file or text file with lyrics")
                
                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(fileManager.currentFileURL == nil)
                
                Button(action: { showingChordLibrary = true }) {
                    Label("Library", systemImage: "music.note.list")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
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
                }
                
                Stepper("Transpose: \(transposeSteps)", value: $transposeSteps, in: -11...11)
                    .onChange(of: transposeSteps) { _, newValue in
                        if newValue != 0 {
                            lyrics = transposer.transpose(lyrics, by: newValue)
                        }
                    }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Chord Selection Panel
    private var chordSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Common Chords")
                .font(.headline)
            
            ForEach(commonChords.keys.sorted(), id: \.self) { category in
                VStack(alignment: .leading) {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(commonChords[category]!, id: \.self) { chord in
                            Button(chord) {
                                selectedChord = chord
                                insertChordAtCursor(chord)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 200)
    }
    
    // MARK: - Text Editor Panel
    private var textEditorPanel: some View {
        VStack {
            CursorTrackingTextEditor(
                text: $lyrics,
                selectedRange: $selectedTextRange,
                pendingSelectedRange: $pendingSelectedTextRange
            )
                .onChange(of: lyrics) { _, _ in
                    // Update chord map on lyrics change
                    chordMap = extractChordsFromLyrics()
                }
        }
        .padding()
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            if isTextOnlyMode {
                Text("Text Only Mode")
                    .foregroundColor(.secondary)
            } else {
                Text("ProPresenter Mode")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !chordMap.isEmpty {
                Text("\(chordMap.count) chords mapped")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .frame(height: 20)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Recent Files Sheet
    private var recentFilesSheet: some View {
        VStack {
            Text("Recent Files")
                .font(.headline)
            
            List(fileManager.recentFiles) { file in
                Button(file.displayName) {
                    Task {
                        do {
                            lyrics = try await fileManager.loadFile(url: file.url)
                            chordMap = extractChordsFromLyrics()
                            fileManager.addRecentFile(file.url)
                            showingRecentFiles = false
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            Button("Clear Recent Files") {
                fileManager.clearRecentFiles()
            }
        }
        .frame(width: 400, height: 300)
    }
    
    // MARK: - File Info Sheet
    private func fileInfoSheet(_ info: ProPresenterFileInfo) -> some View {
        VStack {
            Text("File Info: \(info.filename)")
                .font(.headline)
            
            Text("Slides: \(info.slideCount)")
            
            Text("Has Chords: \(info.hasExistingChords ? "Yes" : "No")")
            
            List(info.textSlides, id: \.id) { slide in
                Text(slide.previewText)
            }
        }
        .frame(width: 400, height: 300)
    }
    
    // MARK: - Load File
    private func loadFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: "pro")!, UTType.text]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            Task {
                do {
                    lyrics = try await fileManager.loadFile(url: url)
                    chordMap = extractChordsFromLyrics()
                    fileManager.addRecentFile(url)
                    fileManager.currentFileURL = url
                    isTextOnlyMode = url.pathExtension.lowercased() != "pro"
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Save File
    private func saveFile() {
        guard let currentURL = fileManager.currentFileURL else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "pro")!]
        savePanel.nameFieldStringValue = "Updated_" + currentURL.lastPathComponent
        
        if savePanel.runModal() == .OK, let saveURL = savePanel.url {
            Task {
                do {
                    try await fileManager.saveFile(lyrics: lyrics, chordMap: chordMap)
                    fileManager.addRecentFile(saveURL)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Show File Info
    private func showFileInfo() {
        guard let url = fileManager.currentFileURL else { return }
        
        Task {
            do {
                fileInfo = try await fileManager.getFileInfo(for: url)
                showingFileInfo = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Insert Chord at Cursor
    private func insertEmptyChordAtCursor() {
        insertTextAtSelectionStart("[]", caretOffset: 1)
    }

    private func insertChordAtCursor(_ chord: String) {
        let chordText = "[\(chord)]"
        insertTextAtSelectionStart(chordText, caretOffset: chordText.utf16.count)
    }

    private func insertTextAtSelectionStart(_ insertedText: String, caretOffset: Int) {
        let nsLyrics = lyrics as NSString
        let insertLocation = max(0, min(selectedTextRange.location, nsLyrics.length))
        let beforeCursor = nsLyrics.substring(to: insertLocation)
        let afterCursor = nsLyrics.substring(from: insertLocation)

        lyrics = beforeCursor + insertedText + afterCursor

        let caretLocation = insertLocation + caretOffset
        selectedTextRange = NSRange(location: caretLocation, length: 0)
        pendingSelectedTextRange = selectedTextRange
    }
    
    // MARK: - Undo/Redo Management
    private func saveToUndoStack() {
        undoStack.append(lyrics)
        if undoStack.count > Self.maxUndoStackSize {
            undoStack.removeFirst()
        }
        redoStack = []
    }
    
    // MARK: - Default Content Setup
    private func setupDefaultContent() {
        lyrics = """
--- Verse 1 ---
Amazing grace how sweet the sound
That saved a wretch like me
I once was lost but now am found
Was blind but now I see

--- Chorus ---
My chains are gone, I've been set free
My God, my Savior has ransomed me
And like a flood His mercy reigns
Unending love, amazing grace
"""
        chordMap = extractChordsFromLyrics()
    }
    
    // MARK: - Key Detection
    private func detectKeyFromLyrics() {
        // Simple key detection logic
        let chords = StringUtilities.extractChords(from: lyrics)
        if let firstChord = chords.first {
            detectedKey = firstChord
        }
    }
    
    // MARK: - Notification Listeners
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: .showRecentFiles,
            object: nil,
            queue: .main
        ) { _ in
            self.showRecentFiles()
        }
        
        NotificationCenter.default.addObserver(
            forName: .showChordLibrary,
            object: nil,
            queue: .main
        ) { _ in
            self.showingChordLibrary = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .insertChord,
            object: nil,
            queue: .main
        ) { _ in
            self.insertEmptyChordAtCursor()
        }
        
        NotificationCenter.default.addObserver(
            forName: .removeAllChords,
            object: nil,
            queue: .main
        ) { _ in
            self.removeAllChords()
        }
        
        NotificationCenter.default.addObserver(
            forName: .transposeUp,
            object: nil,
            queue: .main
        ) { _ in
            if self.transposeSteps < 11 {
                self.transposeSteps += 1
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .transposeDown,
            object: nil,
            queue: .main
        ) { _ in
            if self.transposeSteps > -11 {
                self.transposeSteps -= 1
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .detectKey,
            object: nil,
            queue: .main
        ) { _ in
            self.detectKeyFromLyrics()
        }
    }
    
    private func removeAllChords() {
        saveToUndoStack()
        lyrics = StringUtilities.removeAllChords(from: lyrics)
        AppLogger.chordProcessing("Removed all chords from text")
    }
    
    // Replace the extractChordsFromLyrics() method in ChordEditorView.swift with this fixed version

    private func extractChordsFromLyrics() -> [String: String] {
        var chordMap: [String: String] = [:]
        
        // FIXED: Use regex to split by any section separator pattern like "--- SectionName ---"
        let sectionPattern = #"---\s*[^-]+\s*---"#
        
        // Split lyrics by section separators using regex
        var slides: [String] = []
        
        do {
            let regex = try NSRegularExpression(pattern: sectionPattern, options: [])
            let nsString = lyrics as NSString
            let matches = regex.matches(in: lyrics, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var lastEnd = 0
            
            // Extract content between separators
            for match in matches {
                // Add content before this separator (if any)
                if match.range.location > lastEnd {
                    let contentRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    let content = nsString.substring(with: contentRange)
                    slides.append(content)
                }
                
                // Move to after this separator
                lastEnd = match.range.location + match.range.length
            }
            
            // Add remaining content after the last separator
            if lastEnd < nsString.length {
                let remainingContent = nsString.substring(from: lastEnd)
                slides.append(remainingContent)
            }
            
            // If no separators found, treat entire text as one slide
            if matches.isEmpty {
                slides = [lyrics]
            }
            
        } catch {
            AppLogger.warning("Regex failed, falling back to simple split", error: error)
            // Fallback: treat entire text as one slide
            slides = [lyrics]
        }
        
        // Process each slide, maintaining the exact index mapping
        for (index, slideText) in slides.enumerated() {
            let hasText = slideText.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) != nil
            
            // Skip completely empty slides but maintain index
            if !hasText {
                continue
            }
            
            // Check if this slide has chords (ChordPro format)
            if slideText.contains("[") && slideText.contains("]") {
                // Store the entire slide text with chords intact
                // Use the actual slide index, not a separate counter
                let slideKey = String(index)
                chordMap[slideKey] = slideText
                AppLogger.chordProcessing("Slide \(index): Storing ChordPro text with \(StringUtilities.extractChords(from: slideText).count) chords")
            }
        }
        
        AppLogger.info("Total chord mappings: \(chordMap.count) from \(slides.count) total slides")
        return chordMap
    }
    
    private func showRecentFiles() {
        showingRecentFiles = true
    }
}

private struct CursorTrackingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var pendingSelectedRange: NSRange?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.parent = self

        if textView.string != text {
            textView.string = text
        }

        if let pendingSelectedRange {
            let boundedRange = boundedRange(pendingSelectedRange, textLength: (textView.string as NSString).length)
            textView.setSelectedRange(boundedRange)
            DispatchQueue.main.async {
                self.pendingSelectedRange = nil
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func boundedRange(_ range: NSRange, textLength: Int) -> NSRange {
        let location = max(0, min(range.location, textLength))
        let length = max(0, min(range.length, textLength - location))
        return NSRange(location: location, length: length)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CursorTrackingTextEditor
        weak var textView: NSTextView?

        init(_ parent: CursorTrackingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
            parent.selectedRange = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.selectedRange = textView.selectedRange()
        }
    }
}

#Preview {
    ChordEditorView()
        .frame(width: 800, height: 600)
}
