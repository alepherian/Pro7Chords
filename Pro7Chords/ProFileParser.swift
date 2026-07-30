import SwiftProtobuf
import Foundation
import AppKit  // For NSAttributedString on macOS

// MARK: - Supporting Types for Chord Mapping (moved to top to avoid redeclaration)
struct ParsedChord {
    let position: Int
    let chord: String
}

struct ChordMapping {
    let slideIndex: Int
    let chordProText: String
    let parsedChords: [ParsedChord]
}

private struct SectionChordEdit {
    let sectionName: String
    let slides: [SlideChordEdit]
}

private struct SlideChordEdit {
    let slideNumber: Int
    let chordProText: String
}

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
    
    // MARK: - File Analysis
    func analyzeProPresenterFile(_ url: URL) async throws -> ProPresenterFileInfo {
        AppLogger.info("Analyzing ProPresenter file: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProFileError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        
        do {
            let presentation = try RVData_Presentation(serializedBytes: data)
            
            var slideCount = 0
            var hasChords = false
            var textSlides: [TextSlideInfo] = []
            
            // Count total slides
            slideCount = presentation.cues.count
            
            // Process slides to check for text content and chords
            for (index, cue) in presentation.cues.enumerated() {
                if !cue.actions.isEmpty,
                   let action = cue.actions.first,
                   case .slide(let slideAction) = action.actionTypeData,
                   case .presentation(let presentationSlide) = slideAction.slide {
                    let slide = presentationSlide.baseSlide
                    
                    // Check for text elements
                    if !slide.elements.isEmpty {
                        for slideElement in slide.elements {
                            let element = slideElement.element
                            if element.hasText {
                                let textElement = element.text
                                let previewText = String(decoding: textElement.rtfData.prefix(100), as: UTF8.self) // First 100 chars as preview
                                
                                // Check for chord attributes
                                let slideHasChords = textElement.attributes.customAttributes.contains { attr in
                                    !attr.chord.isEmpty
                                }
                                
                                if slideHasChords {
                                    hasChords = true
                                }
                                
                                textSlides.append(TextSlideInfo(
                                    id: cue.uuid.string,
                                    previewText: previewText.isEmpty ? "Empty slide" : previewText,
                                    hasChords: slideHasChords
                                ))
                            }
                        }
                    }
                }
            }
            
            AppLogger.info("Analysis complete: \(slideCount) slides, \(textSlides.count) text slides, chords: \(hasChords)")
            
            return ProPresenterFileInfo(
                filename: url.lastPathComponent,
                slideCount: slideCount,
                hasExistingChords: hasChords,
                textSlides: textSlides
            )
            
        } catch {
            AppLogger.error("Failed to parse ProPresenter file", error: error)
            throw ProFileError.invalidFormat("Could not parse protobuf data: \(error.localizedDescription)")
        }
    }

    // MARK: - Add Chords to ProPresenter File
    func addChords(to url: URL, lyrics: String, outputURL: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProFileError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        var presentation = try RVData_Presentation(serializedBytes: data)
        let sectionEdits = parseMasterSectionEdits(from: lyrics)

        for sectionEdit in sectionEdits {
            guard let cueGroupIndex = presentation.cueGroups.firstIndex(where: {
                $0.hasGroup && $0.group.name == sectionEdit.sectionName
            }) else {
                AppLogger.warning("No master cue group found for section '\(sectionEdit.sectionName)', skipping")
                continue
            }

            let cueGroup = presentation.cueGroups[cueGroupIndex]
            let masterID = cueGroup.group.uuid.string

            for slideEdit in sectionEdit.slides where slideEdit.chordProText.contains("[") && slideEdit.chordProText.contains("]") {
                let cueIdentifierIndex = slideEdit.slideNumber - 1
                guard cueGroup.cueIdentifiers.indices.contains(cueIdentifierIndex) else {
                    AppLogger.warning("No cue identifier for \(sectionEdit.sectionName) slide \(slideEdit.slideNumber), skipping")
                    continue
                }

                let cueID = cueGroup.cueIdentifiers[cueIdentifierIndex].string
                guard let cueIndex = presentation.cues.firstIndex(where: { $0.uuid.string == cueID }) else {
                    AppLogger.warning("No cue found for \(sectionEdit.sectionName) slide \(slideEdit.slideNumber), cue \(cueID), skipping")
                    continue
                }

                var cue = presentation.cues[cueIndex]
                guard let target = firstPresentationTextElement(in: cue) else {
                    AppLogger.warning("No text element found for \(sectionEdit.sectionName) slide \(slideEdit.slideNumber), skipping")
                    continue
                }

                var action = cue.actions[target.actionIndex]
                guard case .slide(var slideAction) = action.actionTypeData,
                      case .presentation(var presentationSlide) = slideAction.slide else {
                    AppLogger.warning("No presentation slide action found for \(sectionEdit.sectionName) slide \(slideEdit.slideNumber), skipping")
                    continue
                }

                var slide = presentationSlide.baseSlide
                var slideElement = slide.elements[target.elementIndex]
                var graphicsElement = slideElement.element
                var textElement = graphicsElement.text
                let targetElementID = graphicsElement.uuid.string
                let originalPlainText = plainText(from: textElement)

                let chordAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
                if isInstrumentalAnchorText(originalPlainText),
                   let chart = instrumentalChart(from: slideEdit.chordProText) {
                    if originalPlainText.isEmpty,
                       hasMatchingEmptyInstrumentalAttribute(chart: chart, in: textElement.attributes.customAttributes) {
                        chordAttributes = instrumentalChordAttributes(
                            chart: chart,
                            originalPlainText: originalPlainText,
                            existingAttributes: textElement.attributes.customAttributes
                        )
                    } else {
                        textElement.rtfData = instrumentalAnchorRTFData(
                            cocoartfVersion: cocoartfVersion(from: data) ?? cocoartfVersion(from: textElement.rtfData) ?? "2870"
                        )
                        chordAttributes = instrumentalChordAttributes(
                            chart: chart,
                            originalPlainText: ".",
                            existingAttributes: textElement.attributes.customAttributes
                        )
                    }
                } else {
                    chordAttributes = parseChordAttributes(
                        from: slideEdit.chordProText,
                        originalPlainText: originalPlainText,
                        existingAttributes: textElement.attributes.customAttributes
                    )
                }
                textElement.attributes.customAttributes = mergedCustomAttributes(
                    existingAttributes: textElement.attributes.customAttributes,
                    chordAttributes: chordAttributes
                )

                graphicsElement.text = textElement
                slideElement.element = graphicsElement
                slide.elements[target.elementIndex] = slideElement
                presentationSlide.baseSlide = slide
                slideAction.slide = .presentation(presentationSlide)
                action.actionTypeData = .slide(slideAction)
                cue.actions[target.actionIndex] = action
                presentation.cues[cueIndex] = cue

                AppLogger.info("Updated master \(sectionEdit.sectionName) (\(masterID)) slide \(slideEdit.slideNumber), cue \(cueID), text element \(targetElementID)")
            }
        }

        let updatedData: Data = try presentation.serializedBytes()
        try updatedData.write(to: outputURL)

        AppLogger.info("Chords added successfully to \(outputURL.lastPathComponent)")
    }

    func addChords(to url: URL, chordMap: [String: String], outputURL: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProFileError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        var presentation = try RVData_Presentation(serializedBytes: data)
        
        for (slideKey, chordProText) in chordMap {
            guard let index = Int(slideKey), index >= 0, index < presentation.cues.count else {
                AppLogger.warning("Invalid slide index \(slideKey), skipping")
                continue
            }
            
            var cue = presentation.cues[index]
            
            guard !cue.actions.isEmpty,
                  var action = cue.actions.first,
                  case .slide(var slideAction) = action.actionTypeData,
                  case .presentation(var presentationSlide) = slideAction.slide else {
                AppLogger.warning("No slide action found for cue at index \(index), skipping")
                continue
            }
            var slide = presentationSlide.baseSlide
            
            // Find or create text element
            var textElementIndex: Int? = nil
            for (elemIndex, element) in slide.elements.enumerated() {
                if element.element.hasText {
                    textElementIndex = elemIndex
                    break
                }
            }
            
            var textElement: RVData_Graphics.Text
            var graphicsElement: RVData_Graphics.Element
            var slideElement: RVData_Slide.Element
            if let index = textElementIndex {
                slideElement = slide.elements[index]
                graphicsElement = slideElement.element
                textElement = graphicsElement.text
            } else {
                // Create default text element
                graphicsElement = RVData_Graphics.Element()
                textElement = RVData_Graphics.Text()
                // Set default attributes
                textElement.attributes = RVData_Graphics.Text.Attributes()
                textElement.rtfData = Data() // Start with empty RTF
                graphicsElement.text = textElement
                
                slideElement = RVData_Slide.Element()
                slideElement.element = graphicsElement
                slide.elements.append(slideElement)
            }
            
            // Enable and configure ChordPro
            if !textElement.hasChordPro {
                textElement.chordPro = RVData_Graphics.Text.ChordPro()
            }
            textElement.chordPro.enabled = true
            // Set notation and color as per fix
            textElement.chordPro.notation = .chords // Example; adjust if needed
            var chordColor = RVData_Color()
            chordColor.red = 1.0 // Red example
            chordColor.green = 0.0
            chordColor.blue = 0.0
            chordColor.alpha = 1.0
            textElement.chordPro.color = chordColor
            
            // Parse ChordPro with fix for chord-only slides
            let (plainText, customAttributes) = parseChordPro(chordProText)
            
            // Convert plain text to RTF data
            let attributedString = NSAttributedString(string: plainText)
            let rtfRange = NSRange(location: 0, length: attributedString.length)
            textElement.rtfData = try attributedString.data(from: rtfRange, documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
            
            // Apply custom attributes (chords)
            textElement.attributes.customAttributes = customAttributes
            
            // Update the structures back
            graphicsElement.text = textElement
            slideElement.element = graphicsElement
            if let index = textElementIndex {
                slide.elements[index] = slideElement
            } // Else already appended
            presentationSlide.baseSlide = slide
            slideAction.slide = .presentation(presentationSlide)
            action.actionTypeData = .slide(slideAction)
            cue.actions[0] = action
            presentation.cues[index] = cue
        }
        
        // Serialize and write the updated presentation
        let updatedData: Data = try presentation.serializedBytes()
        try updatedData.write(to: outputURL)
        
        AppLogger.info("Chords added successfully to \(outputURL.lastPathComponent)")
    }

    private func firstPresentationTextElement(in cue: RVData_Cue) -> (actionIndex: Int, elementIndex: Int)? {
        for (actionIndex, action) in cue.actions.enumerated() {
            guard case .slide(let slideAction) = action.actionTypeData,
                  case .presentation(let presentationSlide) = slideAction.slide else {
                continue
            }

            if let elementIndex = presentationSlide.baseSlide.elements.firstIndex(where: { $0.element.hasText }) {
                return (actionIndex, elementIndex)
            }
        }

        return nil
    }

    private func parseMasterSectionEdits(from lyrics: String) -> [SectionChordEdit] {
        let nsString = lyrics as NSString
        let sectionPattern = #"(?m)^---\s*([^-]+?)\s*---\s*$"#
        guard let sectionRegex = try? NSRegularExpression(pattern: sectionPattern) else {
            return []
        }

        let fullRange = NSRange(location: 0, length: nsString.length)
        let sectionMatches = sectionRegex.matches(in: lyrics, range: fullRange)

        guard !sectionMatches.isEmpty else {
            return []
        }

        var sections: [SectionChordEdit] = []

        for (sectionIndex, sectionMatch) in sectionMatches.enumerated() {
            guard let sectionNameRange = Range(sectionMatch.range(at: 1), in: lyrics) else {
                continue
            }

            let sectionName = String(lyrics[sectionNameRange])
            let sectionContentStart = sectionMatch.range.location + sectionMatch.range.length
            let sectionContentEnd = sectionIndex + 1 < sectionMatches.count
                ? sectionMatches[sectionIndex + 1].range.location
                : nsString.length

            guard sectionContentEnd >= sectionContentStart else {
                continue
            }

            let sectionContent = nsString.substring(with: NSRange(
                location: sectionContentStart,
                length: sectionContentEnd - sectionContentStart
            ))
            let slides = parseSlideEdits(from: sectionContent)

            sections.append(SectionChordEdit(sectionName: sectionName, slides: slides))
        }

        return sections
    }

    private func parseSlideEdits(from sectionContent: String) -> [SlideChordEdit] {
        let nsString = sectionContent as NSString
        let slidePattern = #"(?m)^Slide\s+(\d+)\s*$"#
        guard let slideRegex = try? NSRegularExpression(pattern: slidePattern) else {
            return []
        }

        let fullRange = NSRange(location: 0, length: nsString.length)
        let slideMatches = slideRegex.matches(in: sectionContent, range: fullRange)

        guard !slideMatches.isEmpty else {
            return []
        }

        var slides: [SlideChordEdit] = []

        for (slideIndex, slideMatch) in slideMatches.enumerated() {
            guard let slideNumberRange = Range(slideMatch.range(at: 1), in: sectionContent),
                  let slideNumber = Int(sectionContent[slideNumberRange]) else {
                continue
            }

            let contentStart = slideMatch.range.location + slideMatch.range.length
            let contentEnd = slideIndex + 1 < slideMatches.count
                ? slideMatches[slideIndex + 1].range.location
                : nsString.length

            guard contentEnd >= contentStart else {
                continue
            }

            let rawContent = nsString.substring(with: NSRange(
                location: contentStart,
                length: contentEnd - contentStart
            ))
            let chordProText = removeStructuralNewlines(from: rawContent)

            slides.append(SlideChordEdit(slideNumber: slideNumber, chordProText: chordProText))
        }

        return slides
    }

    private func removeStructuralNewlines(from text: String) -> String {
        var result = text

        if result.hasPrefix("\r\n") {
            result.removeFirst(2)
        } else if result.hasPrefix("\n") || result.hasPrefix("\r") {
            result.removeFirst()
        }

        while result.hasSuffix("\n") || result.hasSuffix("\r") {
            result.removeLast()
        }

        return result
    }

    private func plainText(from textElement: RVData_Graphics.Text) -> String {
        guard !textElement.rtfData.isEmpty else {
            return ""
        }

        let attributedString = NSAttributedString(rtf: textElement.rtfData, documentAttributes: nil)
        return attributedString?.string ?? ""
    }

    private func isInstrumentalAnchorText(_ plainText: String) -> Bool {
        plainText.isEmpty || plainText == "."
    }

    private func instrumentalChart(from chordProText: String) -> String? {
        let trimmed = chordProText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 else {
            return nil
        }

        let chartStart = trimmed.index(after: trimmed.startIndex)
        let chartEnd = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[chartStart..<chartEnd])
    }

    private func instrumentalChordAttributes(
        chart: String,
        originalPlainText: String,
        existingAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
    ) -> [RVData_Graphics.Text.Attributes.CustomAttribute] {
        let existingChordAttributes = existingAttributes.filter { !$0.chord.isEmpty }

        if let existingAttribute = existingChordAttributes.first(where: {
            $0.chord == chart && $0.range.start == 0 && $0.range.end == 1
        }) {
            return [clampedChordAttribute(existingAttribute, in: originalPlainText)]
        }

        var attribute = RVData_Graphics.Text.Attributes.CustomAttribute()
        attribute.chord = chart
        attribute.range = clampedRange(in: originalPlainText, start: 0, proposedEnd: 1)
        return [attribute]
    }

    private func hasMatchingEmptyInstrumentalAttribute(
        chart: String,
        in attributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
    ) -> Bool {
        attributes.contains {
            $0.chord == chart && $0.range.start == 0 && $0.range.end == 0
        }
    }

    private func instrumentalAnchorRTFData(cocoartfVersion: String) -> Data {
        let rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\cocoartf\(cocoartfVersion)
        \\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}
        {\\colortbl;\\red255\\green255\\blue255;}
        {\\*\\expandedcolortbl;;}
        \\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720\\pardirnatural\\partightenfactor0

        \\f0\\fs24 \\cf0 .}
        """

        return Data(rtf.utf8)
    }

    private func cocoartfVersion(from data: Data) -> String? {
        let text = String(decoding: data, as: UTF8.self)
        guard let range = text.range(of: #"\\cocoartf\d+"#, options: .regularExpression) else {
            return nil
        }

        let token = String(text[range])
        return String(token.dropFirst("\\cocoartf".count))
    }

    private func mergedCustomAttributes(
        existingAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute],
        chordAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
    ) -> [RVData_Graphics.Text.Attributes.CustomAttribute] {
        let nonChordAttributes = existingAttributes.filter { $0.chord.isEmpty }
        return nonChordAttributes + chordAttributes
    }

    private func parseChordAttributes(
        from chordProText: String,
        originalPlainText: String,
        existingAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
    ) -> [RVData_Graphics.Text.Attributes.CustomAttribute] {
        let parsedChords = parseChordPositions(from: chordProText)
        let existingChordAttributes = existingAttributes.filter { !$0.chord.isEmpty }
        var usedExistingAttributeIndexes = Set<Int>()
        var chordAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute] = []

        for parsedChord in parsedChords {
            if let existingIndex = existingChordAttributes.indices.first(where: { index in
                !usedExistingAttributeIndexes.contains(index)
                    && existingChordAttributes[index].chord == parsedChord.chord
                    && Int(existingChordAttributes[index].range.start) == parsedChord.position
            }) {
                usedExistingAttributeIndexes.insert(existingIndex)
                chordAttributes.append(clampedChordAttribute(existingChordAttributes[existingIndex], in: originalPlainText))
                continue
            }

            var attr = RVData_Graphics.Text.Attributes.CustomAttribute()
            attr.chord = parsedChord.chord

            attr.range = shortLocalRange(in: originalPlainText, start: parsedChord.position)
            chordAttributes.append(attr)
        }

        return chordAttributes
    }

    private func parseChordPositions(from chordProText: String) -> [ParsedChord] {
        var parsedChords: [ParsedChord] = []
        var plainTextIndex = 0
        var i = 0
        let characters = Array(chordProText)

        while i < characters.count {
            if characters[i] == "[" {
                var j = i + 1
                while j < characters.count && characters[j] != "]" {
                    j += 1
                }

                if j < characters.count {
                    let chord = String(characters[(i + 1)..<j])
                    parsedChords.append(ParsedChord(position: plainTextIndex, chord: chord))
                    i = j + 1
                    continue
                }
            }

            plainTextIndex += 1
            i += 1
        }

        return parsedChords
    }

    private func clampedChordAttribute(
        _ attribute: RVData_Graphics.Text.Attributes.CustomAttribute,
        in plainText: String
    ) -> RVData_Graphics.Text.Attributes.CustomAttribute {
        var clampedAttribute = attribute
        clampedAttribute.range = clampedRange(
            in: plainText,
            start: Int(attribute.range.start),
            proposedEnd: Int(attribute.range.end)
        )
        return clampedAttribute
    }

    private func shortLocalRange(in plainText: String, start: Int) -> RVData_IntRange {
        let characters = Array(plainText)
        let safeStart = clampedRangeStart(in: characters, start: start)

        var proposedEnd = safeStart
        if !characters.isEmpty {
            if characters[safeStart].isWhitespace {
                proposedEnd += 1
                while proposedEnd < characters.count && !characters[proposedEnd].isWhitespace {
                    proposedEnd += 1
                }
            } else {
                while proposedEnd < characters.count && !characters[proposedEnd].isWhitespace {
                    proposedEnd += 1
                }
            }
        }

        return clampedRange(in: plainText, start: safeStart, proposedEnd: proposedEnd)
    }

    private func clampedRange(in plainText: String, start: Int, proposedEnd: Int) -> RVData_IntRange {
        let characters = Array(plainText)
        let safeStart = clampedRangeStart(in: characters, start: start)
        let textLength = characters.count
        let safeEnd: Int

        if textLength == 0 {
            safeEnd = safeStart
        } else {
            safeEnd = max(safeStart + 1, min(proposedEnd, textLength))
        }

        var range = RVData_IntRange()
        range.start = Int32(safeStart)
        range.end = Int32(safeEnd)
        return range
    }

    private func clampedRangeStart(in characters: [Character], start: Int) -> Int {
        guard !characters.isEmpty else {
            return 0
        }

        let lastNonSpaceIndex = characters.indices.reversed().first { !characters[$0].isWhitespace } ?? characters.index(before: characters.endIndex)
        let boundedStart = max(0, min(start, characters.count - 1))

        if boundedStart > lastNonSpaceIndex {
            return lastNonSpaceIndex
        }

        return boundedStart
    }
    
    // MARK: - ChordPro Parsing with Empty Slide Fix
    private func parseChordPro(_ chordProText: String) -> (String, [RVData_Graphics.Text.Attributes.CustomAttribute]) {
        var plainText = ""
        var chordPositions: [(position: Int, chord: String)] = []
        
        var i = 0
        let characters = Array(chordProText)
        
        while i < characters.count {
            if characters[i] == "[" {
                // Parse chord
                var j = i + 1
                while j < characters.count && characters[j] != "]" {
                    j += 1
                }
                if j < characters.count {
                    let chord = String(characters[(i+1)..<j])
                    let position = plainText.count
                    chordPositions.append((position, chord))
                    i = j + 1
                    
                    // Look ahead: if next is another chord or end, insert space
                    let nextIsChordOrEnd = (i >= characters.count) || (characters[i] == "[")
                    if nextIsChordOrEnd {
                        plainText += " "
                    }
                    continue
                }
            }
            
            // Append non-chord character
            plainText += String(characters[i])
            i += 1
        }
        
        // Build custom attributes with ranges
        var customAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute] = []
        for k in 0..<chordPositions.count {
            var attr = RVData_Graphics.Text.Attributes.CustomAttribute()
            attr.chord = chordPositions[k].chord
            
            var range = RVData_IntRange()
            range.start = Int32(chordPositions[k].position)
            range.end = (k + 1 < chordPositions.count) ? Int32(chordPositions[k+1].position) : Int32(plainText.count)
            
            attr.range = range
            customAttributes.append(attr)
        }
        
        return (plainText, customAttributes)
    }
}
