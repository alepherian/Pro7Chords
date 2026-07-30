import Foundation

// MARK: - Song Section Analyzer
/// Analyzes lyrics to detect and label song sections (Verse, Chorus, Bridge, etc.)
struct SongSectionAnalyzer {
    
    // MARK: - Song Section Types
    enum SectionType: String, CaseIterable {
        case verse = "Verse"
        case chorus = "Chorus"
        case bridge = "Bridge"
        case intro = "Intro"
        case outro = "Outro"
        case preChorus = "Pre-Chorus"
        case tag = "Tag"
        case refrain = "Refrain"
        case interlude = "Interlude"
        case solo = "Solo"
        case unknown = "Slide"
        
        var aliases: [String] {
            switch self {
            case .verse:
                return ["verse", "v", "ver", "stanza"]
            case .chorus:
                return ["chorus", "ch", "chor", "hook", "refrain"]
            case .bridge:
                return ["bridge", "br", "b", "middle 8", "middle eight"]
            case .intro:
                return ["intro", "introduction", "opening"]
            case .outro:
                return ["outro", "ending", "end", "coda"]
            case .preChorus:
                return ["pre-chorus", "prechorus", "pre chorus", "pc", "build"]
            case .tag:
                return ["tag", "ending", "repeat"]
            case .refrain:
                return ["refrain", "ref"]
            case .interlude:
                return ["interlude", "instrumental", "break"]
            case .solo:
                return ["solo", "guitar solo", "piano solo", "instrumental solo"]
            case .unknown:
                return ["slide", "section"]
            }
        }
        
        var color: String {
            switch self {
            case .verse: return "blue"
            case .chorus: return "green"
            case .bridge: return "orange"
            case .intro: return "purple"
            case .outro: return "purple"
            case .preChorus: return "teal"
            case .tag: return "pink"
            case .refrain: return "green"
            case .interlude: return "gray"
            case .solo: return "red"
            case .unknown: return "secondary"
            }
        }
    }
    
    // MARK: - Song Section
    struct SongSection {
        let type: SectionType
        let number: Int
        let content: String
        let range: Range<String.Index>
        
        var label: String {
            if type == .unknown {
                return number == 1 ? "Slide" : "Slide \(number)"
            } else {
                return number == 1 ? type.rawValue : "\(type.rawValue) \(number)"
            }
        }
        
        var separator: String {
            return "--- \(label) ---"
        }
    }
    
    // MARK: - Analysis Results
    struct AnalysisResult {
        let sections: [SongSection]
        let processedText: String
        let originalText: String
        
        var sectionCount: Int { sections.count }
        var sectionTypes: [SectionType] { sections.map { $0.type } }
        var uniqueSectionTypes: Set<SectionType> { Set(sectionTypes) }
    }
    
    // MARK: - Main Analysis Method
    static func analyzeLyrics(_ text: String) -> AnalysisResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // First, try to detect existing section markers
        if let existingResult = analyzeExistingMarkers(trimmedText) {
            return existingResult
        }
        
        // If no existing markers, analyze content to create intelligent sections
        return analyzeContentSections(trimmedText)
    }
    
    // MARK: - Existing Marker Analysis
    private static func analyzeExistingMarkers(_ text: String) -> AnalysisResult? {
        // Check for existing --- Section --- markers
        let sectionPattern = #"---\s*([^-\n]+?)\s*---"#
        guard let regex = try? NSRegularExpression(pattern: sectionPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        guard !matches.isEmpty else { return nil }
        
        var sections: [SongSection] = []
        var sectionCounts: [SectionType: Int] = [:]
        var lastEndIndex = text.startIndex
        var processedText = ""
        
        for (index, match) in matches.enumerated() {
            guard let sectionNameRange = Range(match.range(at: 1), in: text) else { continue }
            
            let sectionName = String(text[sectionNameRange]).trimmingCharacters(in: .whitespaces)
            let sectionType = detectSectionType(from: sectionName)
            let sectionNumber = (sectionCounts[sectionType] ?? 0) + 1
            sectionCounts[sectionType] = sectionNumber
            
            let contentRange = lastEndIndex..<text.index(sectionNameRange.lowerBound, offsetBy: -3) // Before ---
            let content = String(text[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !content.isEmpty {
                let section = SongSection(type: sectionType, number: sectionNumber, content: content, range: contentRange)
                sections.append(section)
                
                processedText += section.separator + "\n\n" + content + "\n\n"
            }
            
            lastEndIndex = text.index(sectionNameRange.upperBound, offsetBy: 3) // After ---
        }
        
        // Add last section if exists
        let lastContent = String(text[lastEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastContent.isEmpty {
            let sectionType = SectionType.unknown
            let sectionNumber = (sectionCounts[sectionType] ?? 0) + 1
            let section = SongSection(type: sectionType, number: sectionNumber, content: lastContent, range: lastEndIndex..<text.endIndex)
            sections.append(section)
            
            processedText += section.separator + "\n\n" + lastContent
        }
        
        return AnalysisResult(sections: sections, processedText: processedText.trimmingCharacters(in: .whitespacesAndNewlines), originalText: text)
    }
    
    // MARK: - Content-Based Section Analysis
    private static func analyzeContentSections(_ text: String) -> AnalysisResult {
        let parts = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
            .components(separatedBy: "\n\n")
        
        var sections: [SongSection] = []
        var sectionCounts: [SectionType: Int] = [:]
        var processedText = ""
        
        for (index, part) in parts.enumerated() {
            let content = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let sectionType = analyzeSectionContent(content)
            let sectionNumber = (sectionCounts[sectionType] ?? 0) + 1
            sectionCounts[sectionType] = sectionNumber
            
            let range = text.range(of: content)! // Safe since we trimmed
            
            let section = SongSection(type: sectionType, number: sectionNumber, content: content, range: range)
            sections.append(section)
            
            if !processedText.isEmpty {
                processedText += "\n\n"
            }
            processedText += section.separator + "\n\n" + content
        }
        
        return AnalysisResult(sections: sections, processedText: processedText, originalText: text)
    }
    
    // MARK: - Section Type Detection
    private static func detectSectionType(from text: String) -> SectionType {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for sectionType in SectionType.allCases {
            for alias in sectionType.aliases {
                if lowercased.contains(alias) {
                    return sectionType
                }
            }
        }
        
        return SectionType.unknown
    }
    
    // MARK: - Content Analysis
    private static func analyzeSectionContent(_ content: String) -> SectionType {
        let lowercased = content.lowercased()
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        
        // Look for explicit section indicators in the content
        for sectionType in SectionType.allCases {
            for alias in sectionType.aliases {
                if lowercased.contains(alias) {
                    return sectionType
                }
            }
        }
        
        // Heuristic analysis based on content patterns
        
        // Check for intro patterns
        if lowercased.contains("intro") || lowercased.contains("beginning") ||
           content.count < 50 { // Short sections are often intros
            return .intro
        }
        
        // Check for outro patterns
        if lowercased.contains("outro") || lowercased.contains("ending") ||
           lowercased.contains("amen") || lowercased.contains("forever") {
            return .outro
        }
        
        // Check for bridge patterns (often different, transitional content)
        if lowercased.contains("bridge") || lowercased.contains("different") ||
           words.count < 20 { // Bridges are often shorter
            return .bridge
        }
        
        // Check for chorus patterns (repetitive, catchy phrases)
        let commonChorusWords = ["come", "sing", "praise", "holy", "love", "heart", "jesus", "god", "lord"]
        let chorusWordCount = words.filter { commonChorusWords.contains($0) }.count
        if chorusWordCount >= 2 {
            return .chorus
        }
        
        // Default to verse for longer content
        return .verse
    }
    
    // MARK: - Text Processing Utilities
    static func convertToSmartLabels(_ text: String) -> String {
        let result = analyzeLyrics(text)
        return result.processedText
    }
    
    static func extractSections(_ text: String) -> [SongSection] {
        let result = analyzeLyrics(text)
        return result.sections
    }
    
    static func getSectionSummary(_ text: String) -> String {
        let result = analyzeLyrics(text)
        let sectionCounts = Dictionary(grouping: result.sections) { $0.type }
            .mapValues { $0.count }
        
        let summary = sectionCounts.map { type, count in
            count == 1 ? type.rawValue : "\(type.rawValue) (\(count))"
        }.joined(separator: ", ")
        
        return summary.isEmpty ? "No sections detected" : summary
    }
}

// MARK: - NSRegularExpression Extension
extension NSRegularExpression {
    func split(_ string: String) -> [String] {
        let range = NSRange(string.startIndex..., in: string)
        let matches = self.matches(in: string, range: range)
        
        var parts: [String] = []
        var lastEnd = string.startIndex
        
        for match in matches {
            if let matchRange = Range(match.range, in: string) {
                // Add the part before the match
                if lastEnd < matchRange.lowerBound {
                    parts.append(String(string[lastEnd..<matchRange.lowerBound]))
                }
                lastEnd = matchRange.upperBound
            }
        }
        
        // Add the remaining part after the last match
        if lastEnd < string.endIndex {
            parts.append(String(string[lastEnd...]))
        }
        
        return parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
