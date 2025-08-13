import SwiftProtobuf
import Foundation
import AppKit  // For NSAttributedString on macOS

// MARK: - ProPresenter File Parser
struct ProFileParser {
    
    // MARK: - Error Types
    enum ProFileError: Error, LocalizedError {
        case invalidFormat(String)
        case missingRootNode
        case missingTextElement
        case corruptedData
        case unsupportedVersion
        case fileNotFound
        case writePermissionDenied
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat(let message):
                return "Invalid ProPresenter file format: \(message)"
            case .missingRootNode:
                return "ProPresenter file is missing required root node"
            case .missingTextElement:
                return "No text element found in slide"
            case .corruptedData:
                return "ProPresenter file data is corrupted"
            case .unsupportedVersion:
                return "Unsupported ProPresenter file version"
            case .fileNotFound:
                return "ProPresenter file not found"
            case .writePermissionDenied:
                return "Permission denied when writing file"
            }
        }
    }
    
    // MARK: - Main Methods
    func addChords(to proFileURL: URL, chords: [String: String], outputURL: URL? = nil) async throws -> URL {
        // Validate input file
        guard FileManager.default.fileExists(atPath: proFileURL.path) else {
            throw ProFileError.fileNotFound
        }
        
        print("🎵 Adding chords to ProPresenter file...")
        print("Received \(chords.count) chord entries")
        for (key, value) in chords {
            print("  Chord mapping [\(key)]: \(value.prefix(50))...")
        }
        
        // Load and parse the protobuf data using RVData_Presentation
        let data = try Data(contentsOf: proFileURL)
        var presentation: RVData_Presentation
        
        do {
            presentation = try RVData_Presentation(serializedBytes: data)
        } catch {
            throw ProFileError.invalidFormat("Failed to parse protobuf: \(error.localizedDescription)")
        }
        
        // Use arrangement for ordered traversal if available
        guard let arrangement = presentation.arrangements.first else {
            throw ProFileError.invalidFormat("No arrangement found in presentation")
        }
        
        var slideIndex = 0  // Only count slides with text content
        
        for groupID in arrangement.groupIdentifiers {
            let groupUUID = groupID.string
            guard let cueGroupIndex = presentation.cueGroups.firstIndex(where: { $0.group.uuid.string == groupUUID }) else {
                print("⚠️ No cue group found for group UUID \(groupUUID.prefix(8))...")
                continue
            }
            let cueGroup = presentation.cueGroups[cueGroupIndex]
            
            for cueIDIndex in 0..<cueGroup.cueIdentifiers.count {
                let cueID = cueGroup.cueIdentifiers[cueIDIndex]
                let cueUUID = cueID.string
                guard let cueIndex = presentation.cues.firstIndex(where: { $0.uuid.string == cueUUID }) else {
                    print("⚠️ No cue found for cue UUID \(cueUUID.prefix(8))...")
                    continue
                }
                var cue = presentation.cues[cueIndex]
                
                print("\nProcessing cue \(cueIndex): '\(cue.name)'")
                var modifiedActions: [RVData_Action] = []
                
                for var action in cue.actions {
                    if action.type == .presentationSlide {
                        // Check if this slide has text content before processing
                        var hasTextContent = false
                        
                        if case .slide(let slideData) = action.actionTypeData {
                            if case .presentation(let presentationSlide) = slideData.slide {
                                let baseSlide = presentationSlide.baseSlide
                                
                                // Check if slide has any text elements with content
                                for element in baseSlide.elements {
                                    if (element.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0 {
                                        let graphicsElement = element.element
                                        if graphicsElement.hasText && !graphicsElement.text.rtfData.isEmpty {
                                            // Try to extract text to see if it's not empty
                                            do {
                                                let attributedString = try NSAttributedString(
                                                    data: graphicsElement.text.rtfData,
                                                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                    documentAttributes: nil
                                                )
                                                let text = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !text.isEmpty {
                                                    hasTextContent = true
                                                    break
                                                }
                                            } catch {
                                                // Try UTF-8 fallback
                                                if let text = String(data: graphicsElement.text.rtfData, encoding: .utf8) {
                                                    let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                                    if !cleanText.isEmpty {
                                                        hasTextContent = true
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Only process slides with text content
                        if hasTextContent {
                            // Use slide index to find corresponding chords
                            let slideKey = String(slideIndex)
                            let chordData = chords[slideKey] ?? ""
                            
                            if !chordData.isEmpty {
                                print("Processing text slide \(slideIndex): adding chords '\(chordData)'")
                            } else {
                                print("Processing text slide \(slideIndex): no chords found")
                            }
                            
                            do {
                                action = try addChordsToSlide(action: action, chordData: chordData)
                                if !chordData.isEmpty {
                                    print("✅ Successfully added chords to text slide \(slideIndex)")
                                }
                            } catch {
                                // Log the error but continue processing other slides
                                print("⚠️ Failed to add chords to text slide \(slideIndex): \(error.localizedDescription)")
                            }
                            
                            slideIndex += 1  // Only increment for slides with text
                        } else {
                            print("Skipping empty slide (no text content) - preserving original")
                            // Keep empty slides in their original position without modification
                        }
                    }
                    modifiedActions.append(action)
                }
                
                cue.actions = modifiedActions
                presentation.cues[cueIndex] = cue
            }
            
            presentation.cueGroups[cueGroupIndex] = cueGroup
        }
        
        // Determine output URL
        let finalOutputURL = outputURL ?? proFileURL.deletingPathExtension()
            .appendingPathComponent("_chords")
            .appendingPathExtension("pro")
        
        // Write the modified data
        do {
            try presentation.serializedData().write(to: finalOutputURL)
            print("✅ Successfully saved ProPresenter file with chords: \(finalOutputURL.lastPathComponent)")
        } catch {
            throw ProFileError.writePermissionDenied
        }
        
        return finalOutputURL
    }
    
    // MARK: - Private Helper Methods
    private func addChordsToSlide(action: RVData_Action, chordData: String) throws -> RVData_Action {
        var modifiedAction = action
        
        // Use the correct slide access structure
        guard case .slide(var slideData) = modifiedAction.actionTypeData else {
            throw ProFileError.missingTextElement
        }
        
        guard case .presentation(var presentationSlide) = slideData.slide else {
            throw ProFileError.missingTextElement
        }
        
        var baseSlide = presentationSlide.baseSlide
        
        // Find text element
        var textElementIndex: Int?
        for (index, element) in baseSlide.elements.enumerated() {
            // Check if this is a text element using the info bit flags
            if (element.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0 {
                textElementIndex = index
                break
            }
        }
        
        guard let elementIndex = textElementIndex else {
            throw ProFileError.missingTextElement
        }
        
        var slideElement = baseSlide.elements[elementIndex]
        var graphicsElement = slideElement.element
        
        // If no chords provided, keep original text unchanged
        guard !chordData.isEmpty else {
            return modifiedAction
        }
        
        // 🎵 ProPresenter-compatible RTF formatting
        let proPresenterRTF = createProPresenterChordRTF(chordData: chordData, originalRTFData: graphicsElement.text.rtfData)
        
        // Update the RTF data
        var newTextData = graphicsElement.text
        newTextData.rtfData = proPresenterRTF
        graphicsElement.text = newTextData
        
        // Update the element back into the slide structure
        slideElement.element = graphicsElement
        baseSlide.elements[elementIndex] = slideElement
        presentationSlide.baseSlide = baseSlide
        slideData.slide = .presentation(presentationSlide)
        modifiedAction.actionTypeData = .slide(slideData)
        
        return modifiedAction
    }
    
    /// Creates ProPresenter-compatible RTF that hides chords from audience but shows them to operators
    private func createProPresenterChordRTF(chordData: String, originalRTFData: Data) -> Data {
        // Extract original formatting attributes
        var originalAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 117), // Default ProPresenter font size
            .foregroundColor: NSColor.white,
            .strokeWidth: -2.0, // Outline
            .strokeColor: NSColor.black
        ]
        
        if !originalRTFData.isEmpty {
            do {
                let existingAttributedString = try NSAttributedString(
                    data: originalRTFData,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                
                if existingAttributedString.length > 0 {
                    originalAttributes = existingAttributedString.attributes(at: 0, effectiveRange: nil)
                }
            } catch {
                print("Warning: Could not extract original formatting: \(error)")
            }
        }
        
        // Create properly formatted attributed string
        let formattedText = formatChordProForProPresenter(chordData)
        let attributedString = NSMutableAttributedString(string: formattedText)
        
        // Apply base formatting to entire text
        attributedString.addAttributes(originalAttributes, range: NSRange(location: 0, length: attributedString.length))
        
        // Apply special formatting to chord markers for ProPresenter compatibility
        let chordPattern = #"\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: chordPattern) {
            let matches = regex.matches(in: formattedText, range: NSRange(location: 0, length: formattedText.count))
            
            for match in matches {
                let chordRange = match.range
                
                // Make chord markers invisible to audience but visible to operators
                // This uses ProPresenter's internal chord formatting
                var chordAttributes = originalAttributes
                
                // Set chord color to transparent for audience (but ProPresenter will still show them to operators)
                chordAttributes[.foregroundColor] = NSColor.clear
                chordAttributes[.strokeColor] = NSColor.clear
                
                // Add special ProPresenter chord marker attributes
                // These are based on the RTF structure seen in your file
                if let originalFont = originalAttributes[.font] as? NSFont {
                    chordAttributes[.font] = NSFont.systemFont(ofSize: originalFont.pointSize * 0.7)
                }
                
                attributedString.addAttributes(chordAttributes, range: chordRange)
            }
        }
        
        // Generate RTF data
        do {
            return try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        } catch {
            print("Warning: RTF generation failed, using plain text: \(error)")
            return chordData.data(using: .utf8) ?? Data()
        }
    }
    
    /// Formats ChordPro text for ProPresenter display
    private func formatChordProForProPresenter(_ chordData: String) -> String {
        // ProPresenter expects clean ChordPro format
        // Just return the ChordPro text as-is - the RTF formatting will handle the display
        return chordData
    }
    
    private func insertChordsIntoText(_ text: String, chords: String) -> String {
        // If the text already contains chords, return as-is (ChordPro format)
        if text.contains("[") && text.contains("]") {
            return text
        }
        
        // If no inline chords in the original text, but we have chord data,
        // just return the original text since ProPresenter will handle ChordPro format
        // This function should mainly preserve existing chord placements
        return text
    }
    
    private func formatChordsForInsertion(_ chordData: String) -> String {
        guard !chordData.isEmpty else { return "" }
        
        // Split chords and format them
        let chords = chordData.split(separator: " ")
        let formattedChords = chords.map { "[\($0)]" }.joined(separator: " ")
        
        return formattedChords + "\n"
    }
    
    // MARK: - File Analysis
    func analyzeProPresenterFile(_ url: URL) async throws -> ProPresenterFileInfo {
        let data = try Data(contentsOf: url)
        
        // Use RVData_Presentation instead of RVData_PlaylistDocument
        let presentation = try RVData_Presentation(serializedBytes: data)
        
        var slideCount = 0
        var hasChords = false
        var textSlides: [SlideInfo] = []
        
        // Use arrangement for ordered traversal if available
        guard let arrangement = presentation.arrangements.first else {
            throw ProFileError.invalidFormat("No arrangement found in presentation")
        }
        
        for groupID in arrangement.groupIdentifiers {
            let groupUUID = groupID.string
            guard let cueGroup = presentation.cueGroups.first(where: { $0.group.uuid.string == groupUUID }) else {
                continue
            }
            
            for cueID in cueGroup.cueIdentifiers {
                let cueUUID = cueID.string
                guard let cue = presentation.cues.first(where: { $0.uuid.string == cueUUID }) else {
                    continue
                }
                
                for action in cue.actions {
                    if action.type == .presentationSlide {
                        slideCount += 1
                        
                        // Use the correct slide access structure
                        if case .slide(let slideData) = action.actionTypeData {
                            if case .presentation(let presentationSlide) = slideData.slide {
                                let baseSlide = presentationSlide.baseSlide
                                
                                // Find text element
                                for element in baseSlide.elements {
                                    // Check if this is a text element using the info bit flags
                                    if (element.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0 {
                                        let graphicsElement = element.element
                                        if graphicsElement.hasText {
                                            let text = String(data: graphicsElement.text.rtfData, encoding: .utf8) ?? ""
                                            let containsChords = text.contains("[") && text.contains("]")
                                            if containsChords { hasChords = true }
                                            
                                            textSlides.append(SlideInfo(
                                                id: cue.uuid.string,
                                                text: text,
                                                hasChords: containsChords
                                            ))
                                            break // Only process first text element per slide
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return ProPresenterFileInfo(
            filename: url.lastPathComponent,
            slideCount: slideCount,
            hasExistingChords: hasChords,
            textSlides: textSlides
        )
    }
    
    // MARK: - Extract Chords
    func extractChords(from text: String) -> [String] {
        let chordPattern = #"\[([^\]]+)\]"#
        let regex = try? NSRegularExpression(pattern: chordPattern)
        let range = NSRange(text.startIndex..., in: text)
        
        var chords: [String] = []
        
        regex?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chord = String(text[chordRange])
            chords.append(chord)
        }
        
        return chords
    }
}

// MARK: - Supporting Types
struct ProPresenterFileInfo {
    let filename: String
    let slideCount: Int
    let hasExistingChords: Bool
    let textSlides: [SlideInfo]
}

struct SlideInfo: Identifiable {
    let id: String
    let text: String
    let hasChords: Bool
    
    var previewText: String {
        // Return first line or first 50 characters for preview
        let firstLine = text.split(separator: "\n").first ?? ""
        return String(firstLine.prefix(50))
    }
}
