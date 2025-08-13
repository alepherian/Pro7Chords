import Foundation
import SwiftUI
import SwiftProtobuf

extension FileManager {
    func fileSize(url: URL) -> String? {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
        }
        return nil
    }
}

// MARK: - File Manager Service
@MainActor
class FileManagerService: ObservableObject {
    @Published var recentFiles: [RecentFile] = []
    @Published var currentFileURL: URL?
    @Published var isLoading = false
    
    private let maxRecentFiles = 10
    private let recentFilesKey = "RecentFiles"
    
    init() {
        loadRecentFiles()
    }
    
    // MARK: - ProPresenter Arrangement-Based Extraction
    private func extractLyricsFromArrangement(_ presentation: RVData_Presentation) async throws -> String {
        print("🎵 Extracting lyrics using arrangement order...")
        
        guard let arrangement = presentation.arrangements.first else {
            print("⚠️ No arrangements found, falling back to cue order")
            return try await extractLyricsFromCues(presentation)
        }
        
        print("Using arrangement: '\(arrangement.name)' with \(arrangement.groupIdentifiers.count) groups")
        
        // Create maps for fast lookups
        var cueGroupMap: [String: RVData_Presentation.CueGroup] = [:]
        for cueGroup in presentation.cueGroups {
            if cueGroup.hasGroup {
                cueGroupMap[cueGroup.group.uuid.string] = cueGroup
            }
        }
        
        var cueMap: [String: RVData_Cue] = [:]
        for cue in presentation.cues {
            cueMap[cue.uuid.string] = cue
        }
        
        var allLyrics: [String] = []
        
        // Follow the arrangement order
        for (groupIndex, groupUUID) in arrangement.groupIdentifiers.enumerated() {
            let groupUUIDString = groupUUID.string
            print("Processing arrangement group \(groupIndex + 1): \(groupUUIDString.prefix(8))...")
            
            // Find the cue group that matches this arrangement group
            guard let cueGroup = cueGroupMap[groupUUIDString] else {
                print("  ⚠️ No cue group found for group UUID")
                continue
            }
            
            print("  ✅ Found cue group: '\(cueGroup.group.name)' with \(cueGroup.cueIdentifiers.count) cues")
            
            // Extract text from all cues in this group (in order)
            for (cueIndex, cueUUID) in cueGroup.cueIdentifiers.enumerated() {
                let cueUUIDString = cueUUID.string
                
                guard let cue = cueMap[cueUUIDString] else {
                    print("    ⚠️ No cue found for cue UUID \(cueUUIDString.prefix(8))...")
                    allLyrics.append("") // Add placeholder
                    continue
                }
                
                print("    Processing cue \(cueIndex + 1): \(cueUUIDString.prefix(8))...")
                
                if let slideText = extractTextFromCue(cue, cueIndex: cueIndex) {
                    allLyrics.append(slideText)
                    print("      📝 Extracted: \(slideText.prefix(30))...")
                } else {
                    allLyrics.append("") // Add placeholder for empty slides
                    print("      ⚠️ No text found")
                }
            }
        }
        
        print("\n📈 Summary: Extracted \(allLyrics.count) slides using arrangement order")
        print("📈 Non-empty slides: \(allLyrics.filter { !$0.isEmpty }.count)")
        
        if allLyrics.filter({ !$0.isEmpty }).isEmpty {
            throw FileManagerError.invalidProPresenterFormat("No text content found in any slides")
        }
        
        // Combine all slides with clear separators
        let combinedLyrics = allLyrics.joined(separator: "\n\n--- Next Slide ---\n\n")
        print("✅ Successfully extracted \(combinedLyrics.count) characters in correct arrangement order")
        
        return combinedLyrics
    }
    
    private func extractTextFromCue(_ cue: RVData_Cue, cueIndex: Int) -> String? {
        print("Processing cue \(cueIndex + 1)/total: '\(cue.name)'")
        
        for (actionIndex, action) in cue.actions.enumerated() {
            print("  Checking action \(actionIndex + 1): type = \(action.type)")
            
            // Look for presentation slide actions
            if action.type == .presentationSlide {
                print("  ✅ Found presentation slide action!")
                
                // Get the slide data
                if case .slide(let slideData) = action.actionTypeData {
                    if case .presentation(let presentationSlide) = slideData.slide {
                        print("    Processing presentation slide...")
                        
                        let baseSlide = presentationSlide.baseSlide
                        print("    Slide has \(baseSlide.elements.count) elements")
                        
                        var slideText = ""
                        
                        // Extract text from all elements in this slide
                        for (elementIndex, slideElement) in baseSlide.elements.enumerated() {
                            print("    Checking element \(elementIndex + 1): info = \(slideElement.info)")
                            
                            // Check if this is a text element
                            if (slideElement.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0 {
                                print("    ✅ Found text element!")
                                
                                let graphicsElement = slideElement.element
                                if graphicsElement.hasText {
                                    let textData = graphicsElement.text
                                    if !textData.rtfData.isEmpty {
                                        print("      RTF data size: \(textData.rtfData.count) bytes")
                                        
                                        // Try RTF parsing first
                                        do {
                                            let attributedString = try NSAttributedString(
                                                data: textData.rtfData,
                                                options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                documentAttributes: nil
                                            )
                                            let text = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !text.isEmpty {
                                                print("      ✅ Extracted RTF text: \"\(text.prefix(50))...\"")
                                                slideText += text + "\n"
                                            }
                                        } catch {
                                            print("      RTF parsing failed: \(error)")
                                            // Try plain text fallback
                                            if let stringData = String(data: textData.rtfData, encoding: .utf8) {
                                                let text = stringData.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !text.isEmpty {
                                                    print("      ✅ Extracted as plain text: \"\(text.prefix(50))...\"")
                                                    slideText += text + "\n"
                                                }
                                            }
                                        }
                                    } else {
                                        print("      Text element has no RTF data")
                                    }
                                } else {
                                    print("      Graphics element has no text property")
                                }
                            }
                        }
                        
                        // Return the extracted text
                        let trimmedText = slideText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedText.isEmpty {
                            print("    📝 Extracted slide text (\(trimmedText.count) characters)")
                            return trimmedText
                        } else {
                            print("    ⚠️ Slide had no text content")
                            return nil
                        }
                    } else {
                        print("    Slide is not a presentation slide (might be prop slide)")
                    }
                } else {
                    print("    Action doesn't contain slide data")
                }
            }
        }
        
        print("  ⚠️ No presentation slide action found in cue")
        return nil
    }
    
    private func extractLyricsFromCues(_ presentation: RVData_Presentation) async throws -> String {
        print("📋 Extracting lyrics using cue order (may not match ProPresenter display)...")
        
        var allLyrics: [String] = []
        
        // Extract lyrics from ALL presentation slides IN ORDER
        for (cueIndex, cue) in presentation.cues.enumerated() {
            if let slideText = extractTextFromCue(cue, cueIndex: cueIndex) {
                allLyrics.append(slideText)
            } else {
                // Add empty placeholder to maintain slide order
                allLyrics.append("")
            }
        }
        
        print("📈 Summary: Found \(presentation.cues.count) slides total with \(allLyrics.filter { !$0.isEmpty }.count) containing text")
        
        if allLyrics.filter({ !$0.isEmpty }).isEmpty {
            throw FileManagerError.invalidProPresenterFormat("No text content found in any slides")
        }
        
        // Combine all slides with clear separators, preserving empty slides for correct order
        let combinedLyrics = allLyrics.joined(separator: "\n\n--- Next Slide ---\n\n")
        print("✅ Successfully extracted \(combinedLyrics.count) characters from \(allLyrics.count) slides (\(allLyrics.filter { !$0.isEmpty }.count) with text)")
        
        return combinedLyrics
    }
    
    // MARK: - Recent Files Management
    func addRecentFile(_ url: URL) {
        let newFile = RecentFile(url: url)
        
        // Remove existing entry if present
        recentFiles.removeAll { $0.url == url }
        
        // Add to beginning
        recentFiles.insert(newFile, at: 0)
        
        // Limit to max files
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        
        saveRecentFiles()
    }
    
    func removeRecentFile(_ file: RecentFile) {
        recentFiles.removeAll { $0.id == file.id }
        saveRecentFiles()
    }
    
    func clearRecentFiles() {
        recentFiles.removeAll()
        saveRecentFiles()
    }
    
    private func loadRecentFiles() {
        guard let data = UserDefaults.standard.data(forKey: recentFilesKey),
              let files = try? JSONDecoder().decode([RecentFile].self, from: data) else {
            return
        }
        
        // Filter out files that no longer exist
        recentFiles = files.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        if recentFiles.count != files.count {
            saveRecentFiles() // Update if some files were removed
        }
    }
    
    private func saveRecentFiles() {
        guard let data = try? JSONEncoder().encode(recentFiles) else { return }
        UserDefaults.standard.set(data, forKey: recentFilesKey)
    }
    
    // MARK: - File Operations
    func loadFile(from url: URL) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileManagerError.fileNotFound
        }
        
        do {
            let content: String
            
            if url.pathExtension.lowercased() == "pro" {
                // Try to load ProPresenter file, but provide fallback
                do {
                    content = try await loadProPresenterFile(from: url)
                } catch {
                    // If ProPresenter parsing fails, offer a text-only mode
                    print("ProPresenter parsing failed: \(error.localizedDescription)")
                    print("Falling back to text-only mode")
                    
                    // Return helpful placeholder text with slide structure
                    content = """
                        # ProPresenter File - Text Mode
                        # Original file: \(url.lastPathComponent)
                        # File size: \(FileManager.default.fileSize(url: url) ?? "unknown")
                        #
                        # Instructions:
                        # 1. Open your ProPresenter file normally
                        # 2. Go to each slide and copy the lyrics
                        # 3. Paste them below in this format:
                        #
                        # === Slide 1 ===
                        # [paste slide 1 lyrics here]
                        #
                        # === Slide 2 ===
                        # [paste slide 2 lyrics here]
                        #
                        # Use [C], [Am], [F], [G] format for chords
                        # The app will help you transpose and analyze!
                        
                        === Slide 1 ===
                        
                        
                        === Slide 2 ===
                        
                        
                        === Slide 3 ===
                        
                        
                        === Slide 4 ===
                        
                        
                        """
                    
                    // Still set current URL so save will work
                    currentFileURL = url
                    addRecentFile(url)
                    
                    // Re-throw with user-friendly message but allow app to continue
                    throw FileManagerError.invalidProPresenterFormat(
                        "ProPresenter file format not supported. Switched to text-only mode - you can now paste lyrics and add chords manually.")
                }
            } else {
                content = try String(contentsOf: url, encoding: .utf8)
            }
            
            currentFileURL = url
            addRecentFile(url)
            return content
            
        } catch {
            throw FileManagerError.loadFailed(error.localizedDescription)
        }
    }
    
    func saveFile(content: String, to url: URL, chords: [String: String] = [:]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if url.pathExtension.lowercased() == "pro" {
                guard let originalURL = currentFileURL else {
                    throw FileManagerError.noOriginalFile
                }
                try await saveProPresenterFile(from: originalURL, chords: chords, to: url)
            } else {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
            
            addRecentFile(url)
            
        } catch {
            throw FileManagerError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - ProPresenter File Handling
    private func loadProPresenterFile(from url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        
        // Debug: Print file information
        print("=== ProPresenter File Analysis ===")
        print("File: \(url.lastPathComponent)")
        print("Size: \(data.count) bytes")
        print("First 32 bytes: \(data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Check file signature
        let signature = data.prefix(4)
        let sigHex = signature.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("File signature: \(sigHex)")
        
        // Check for common formats
        if signature == Data([0x50, 0x4B, 0x03, 0x04]) {
            print("🗃️ File is ZIP-compressed")
            return try await handleZippedProPresenterFile(data: data, url: url)
        } else if signature == Data([0x1F, 0x8B]) {
            print("📦 File is GZIP-compressed")
            throw FileManagerError.invalidProPresenterFormat("GZIP-compressed ProPresenter files are not yet supported. Please export as uncompressed .pro file.")
        } else if data.prefix(10).contains(where: { $0 == 0x7B }) { // Contains '{' - might be JSON
            print("🔤 File might be JSON format")
            return try await handleJSONProPresenterFile(data: data)
        } else if data.prefix(10).contains(where: { $0 == 0x3C }) { // Contains '<' - might be XML
            print("📄 File might be XML format")
            return try await handleXMLProPresenterFile(data: data)
        } else {
            print("🔬 Attempting protobuf parsing...")
            return try await handleProtobufProPresenterFile(data: data)
        }
    }
    
    private func handleZippedProPresenterFile(data: Data, url: URL) async throws -> String {
        // ProPresenter files are often ZIP archives containing JSON or other formats
        // For now, provide instructions to user
        throw FileManagerError.invalidProPresenterFormat(
            """
            This ProPresenter file is ZIP-compressed.
            
            To use it with this app:
            1. Rename \(url.lastPathComponent) to \(url.deletingPathExtension().lastPathComponent).zip
            2. Double-click to extract it
            3. Look for .json or .pro files inside
            4. Try opening those files instead
            
            Or copy/paste lyrics directly from ProPresenter.
            """)
    }
    
    private func handleJSONProPresenterFile(data: Data) async throws -> String {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw FileManagerError.invalidProPresenterFormat("Could not read JSON file")
        }
        
        // Try to extract text from JSON
        // This is a basic implementation - you might need to adjust based on your JSON structure
        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            var extractedText = "# Extracted from ProPresenter JSON\n\n"
            
            // Look for common text fields in ProPresenter JSON
            if let slides = json["slides"] as? [[String: Any]] {
                for slide in slides {
                    if let text = slide["text"] as? String {
                        extractedText += text + "\n\n"
                    }
                }
            }
            
            return extractedText.isEmpty ? "No text found in JSON" : extractedText
        }
        
        throw FileManagerError.invalidProPresenterFormat("Could not parse JSON ProPresenter file")
    }
    
    private func handleXMLProPresenterFile(data: Data) async throws -> String {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw FileManagerError.invalidProPresenterFormat("Could not read XML file")
        }
        
        // Basic XML text extraction - look for common ProPresenter XML patterns
        let textPattern = #"<text[^>]*>([^<]*)</text>"#
        let regex = try NSRegularExpression(pattern: textPattern, options: .caseInsensitive)
        let range = NSRange(xmlString.startIndex..., in: xmlString)
        
        var extractedText = "# Extracted from ProPresenter XML\n\n"
        
        regex.enumerateMatches(in: xmlString, range: range) { match, _, _ in
            guard let match = match,
                  let textRange = Range(match.range(at: 1), in: xmlString) else { return }
            
            let text = String(xmlString[textRange])
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedText += text + "\n\n"
            }
        }
        
        return extractedText.isEmpty ? "No text found in XML" : extractedText
    }
    
    private func handleProtobufProPresenterFile(data: Data) async throws -> String {
        print("🔬 Attempting correct ProPresenter 7 protobuf parsing...")
        
        do {
            // Parse as Presentation (not PlaylistDocument!)
            let presentation = try RVData_Presentation(serializedBytes: data)
            print("✅ Successfully parsed as Presentation!")
            print("Presentation name: \(presentation.name)")
            print("Found \(presentation.cues.count) cues")
            
            // 🔍 DEEP DIVE: Investigate arrangement data
            print("\n🔍 === PROTOBUF INVESTIGATION ===")
            investigateArrangementData(presentation)
            investigateSlideGroups(presentation)
            investigateCueStructure(presentation)
            print("🔍 === END INVESTIGATION ===\n")
            
            // Check if there's arrangement data that defines slide order
            if !presentation.arrangements.isEmpty {
                print("🎵 Found arrangement data - using arrangement order")
                return try await extractLyricsFromArrangement(presentation)
            } else {
                print("⚠️ No arrangement found - using cue order (may not match ProPresenter display order)")
                return try await extractLyricsFromCues(presentation)
            }
            
        } catch let error as SwiftProtobuf.BinaryDecodingError {
            print("❌ Protobuf decoding failed: \(error)")
            print("Error code: \(error.localizedDescription)")
            
            throw FileManagerError.invalidProPresenterFormat(
                """
                ProPresenter protobuf schema mismatch.
                
                Your ProPresenter version uses a different internal format than expected.
                
                Debug info:
                • File size: \(data.count) bytes
                • Protobuf signature: \(data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " "))
                • Error: \(error.localizedDescription)
                
                The protobuf definitions may need updating for your ProPresenter version.
                """)
        } catch {
            throw FileManagerError.loadFailed("ProPresenter file parsing failed: \(error.localizedDescription)")
        }
    }
    
    private func saveProPresenterFile(from originalURL: URL, chords: [String: String], to saveURL: URL) async throws {
        let parser = ProFileParser()
        _ = try await parser.addChords(to: originalURL, chords: chords, outputURL: saveURL)
    }
    
    // MARK: - Protobuf Investigation Functions
    private func investigateArrangementData(_ presentation: RVData_Presentation) {
        print("📁 === ARRANGEMENTS ===")
        print("Number of arrangements: \(presentation.arrangements.count)")
        
        for (index, arrangement) in presentation.arrangements.enumerated() {
            print("\n  Arrangement \(index + 1):")
            print("    Name: '\(arrangement.name)'")
            print("    UUID: \(arrangement.uuid.string)")
            print("    Group identifiers count: \(arrangement.groupIdentifiers.count)")
            
            for (groupIndex, groupID) in arrangement.groupIdentifiers.prefix(10).enumerated() {
                print("        Group \(groupIndex + 1): \(groupID.string.prefix(8))...")
            }
            
            if arrangement.groupIdentifiers.count > 10 {
                print("        ... and \(arrangement.groupIdentifiers.count - 10) more groups")
            }
        }
    }
    
    private func investigateSlideGroups(_ presentation: RVData_Presentation) {
        print("\n📋 === CUE GROUPS ===")
        print("Number of cue groups: \(presentation.cueGroups.count)")
        
        for (index, cueGroup) in presentation.cueGroups.enumerated() {
            print("\n  Cue Group \(index + 1):")
            if cueGroup.hasGroup {
                print("    Group name: '\(cueGroup.group.name)'")
                print("    Group UUID: \(cueGroup.group.uuid.string)")
            }
            print("    Cue identifiers count: \(cueGroup.cueIdentifiers.count)")
            
            for (cueIndex, cueID) in cueGroup.cueIdentifiers.prefix(5).enumerated() {
                print("      Cue \(cueIndex + 1): \(cueID.string.prefix(8))...")
            }
        }
    }
    
    private func investigateCueStructure(_ presentation: RVData_Presentation) {
        print("\n🎬 === CUE STRUCTURE ===")
        
        for (index, cue) in presentation.cues.prefix(5).enumerated() {
            print("\n  Cue \(index + 1):")
            print("    Name: '\(cue.name)'")
            print("    UUID: \(cue.uuid.string)")
            print("    Actions count: \(cue.actions.count)")
        }
        
        if presentation.cues.count > 5 {
            print("    ... and \(presentation.cues.count - 5) more cues")
        }
        
        // 🔑 KEY INVESTIGATION: Map arrangement order to cues
        if !presentation.arrangements.isEmpty {
            print("\n🔑 === ARRANGEMENT TO CUE MAPPING ===")
            let arrangement = presentation.arrangements[0]
            print("Using arrangement: '\(arrangement.name)'")
            print("Arrangement has \(arrangement.groupIdentifiers.count) group identifiers")
            
            // Create a map of cue UUIDs to cue indices for quick lookup
            var cueMap: [String: (index: Int, cue: RVData_Cue)] = [:]
            for (index, cue) in presentation.cues.enumerated() {
                cueMap[cue.uuid.string] = (index: index, cue: cue)
            }
            
            print("\nMapping arrangement order to cues:")
            for (arrangementIndex, groupID) in arrangement.groupIdentifiers.enumerated() {
                let groupUUID = groupID.string
                
                if let mappedCue = cueMap[groupUUID] {
                    print("  ✅ Arrangement position \(arrangementIndex + 1) → Cue \(mappedCue.index + 1): '\(mappedCue.cue.name)'")
                } else {
                    print("  ❌ Arrangement position \(arrangementIndex + 1) → No matching cue for \(groupUUID.prefix(8))...")
                }
            }
        }
    }
}

// MARK: - File Manager Errors
enum FileManagerError: Error, LocalizedError {
    case fileNotFound
    case loadFailed(String)
    case saveFailed(String)
    case invalidProPresenterFormat(String)
    case noOriginalFile
    case unsupportedFileType
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .loadFailed(let message):
            return "Failed to load file: \(message)"
        case .saveFailed(let message):
            return "Failed to save file: \(message)"
        case .invalidProPresenterFormat(let message):
            return "Invalid ProPresenter file: \(message)"
        case .noOriginalFile:
            return "No original file to reference for ProPresenter export"
        case .unsupportedFileType:
            return "Unsupported file type"
        }
    }
}
