import Foundation

// MARK: - Chord Model
struct Chord: Equatable, Hashable {
    let root: String
    let quality: ChordQuality
    let extensions: [String]
    let bassNote: String?
    
    enum ChordQuality: String, CaseIterable {
        case major = ""
        case minor = "m"
        case diminished = "dim"
        case augmented = "aug"
        case dominant7 = "7"
        case major7 = "maj7"
        case minor7 = "m7"
        case sus2 = "sus2"
        case sus4 = "sus4"
        
        var displayName: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            case .diminished: return "Diminished"
            case .augmented: return "Augmented"
            case .dominant7: return "Dominant 7th"
            case .major7: return "Major 7th"
            case .minor7: return "Minor 7th"
            case .sus2: return "Suspended 2nd"
            case .sus4: return "Suspended 4th"
            }
        }
    }
    
    init?(from string: String) {
        let chordPattern = #"^([A-G][#b]?)(m|maj|dim|aug|sus[24]?|add[0-9]|[0-9]+)*(\/[A-G][#b]?)?$"#
        guard string.range(of: chordPattern, options: .regularExpression) != nil else {
            return nil
        }
        
        // Parse bass note (slash chord)
        let components = string.split(separator: "/")
        let mainChord = String(components[0])
        self.bassNote = components.count > 1 ? String(components[1]) : nil
        
        // Extract root note
        let rootPattern = #"^[A-G][#b]?"#
        guard let rootRange = mainChord.range(of: rootPattern, options: .regularExpression) else {
            return nil
        }
        self.root = String(mainChord[rootRange])
        
        // Extract quality and extensions
        let remainder = String(mainChord[rootRange.upperBound...])
        
        // Determine quality
        if remainder.hasPrefix("maj7") {
            self.quality = .major7
            self.extensions = Array(remainder.dropFirst(4).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("m7") {
            self.quality = .minor7
            self.extensions = Array(remainder.dropFirst(2).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("dim") {
            self.quality = .diminished
            self.extensions = Array(remainder.dropFirst(3).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("aug") {
            self.quality = .augmented
            self.extensions = Array(remainder.dropFirst(3).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("sus2") {
            self.quality = .sus2
            self.extensions = Array(remainder.dropFirst(4).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("sus4") {
            self.quality = .sus4
            self.extensions = Array(remainder.dropFirst(4).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("m") {
            self.quality = .minor
            self.extensions = Array(remainder.dropFirst(1).split(separator: ",").map(String.init))
        } else if remainder.hasPrefix("7") {
            self.quality = .dominant7
            self.extensions = Array(remainder.dropFirst(1).split(separator: ",").map(String.init))
        } else {
            self.quality = .major
            self.extensions = Array(remainder.split(separator: ",").map(String.init))
        }
    }
    
    var description: String {
        let baseChord = root + quality.rawValue + extensions.joined()
        if let bassNote = bassNote {
            return "\(baseChord)/\(bassNote)"
        } else {
            return baseChord
        }
    }
}

// MARK: - Chord Position
struct ChordPosition: Identifiable, Codable {
    let id = UUID()
    let chord: String
    let slideId: String
    let timestamp: Date
    let position: Int // Character position in lyrics
    
    // Exclude id from coding since it's auto-generated
    private enum CodingKeys: String, CodingKey {
        case chord, slideId, timestamp, position
    }
    
    init(chord: String, slideId: String, position: Int) {
        self.chord = chord
        self.slideId = slideId
        self.position = position
        self.timestamp = Date()
    }
}

// MARK: - Recent File
struct RecentFile: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let lastOpened: Date
    let title: String
    
    // Exclude id from coding since it's auto-generated
    private enum CodingKeys: String, CodingKey {
        case url, lastOpened, title
    }
    
    init(url: URL) {
        self.url = url
        self.lastOpened = Date()
        self.title = url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Chord Validation
extension Chord {
    
    /// Validates if a string represents a valid chord
    static func isValid(_ string: String) -> Bool {
        return Chord(from: string) != nil
    }
    
    /// Gets the chord complexity level
    var complexity: ChordComplexity {
        let hasExtensions = !extensions.isEmpty
        let isSlashChord = bassNote != nil
        let isAdvancedQuality = [.diminished, .augmented, .major7, .minor7].contains(quality)
        
        if hasExtensions || (isSlashChord && isAdvancedQuality) {
            return .advanced
        } else if isSlashChord || isAdvancedQuality {
            return .intermediate
        } else {
            return .basic
        }
    }
    
    enum ChordComplexity: String, CaseIterable {
        case basic = "Basic"
        case intermediate = "Intermediate" 
        case advanced = "Advanced"
        
        var color: String {
            switch self {
            case .basic: return "green"
            case .intermediate: return "orange"
            case .advanced: return "red"
            }
        }
    }
}

// MARK: - Chord Progression
struct ChordProgression {
    let chords: [Chord]
    let key: String?
    
    init(from text: String) {
        // Extract chords from ChordPro format text
        let chordPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            self.chords = []
            self.key = nil
            return
        }
        
        let range = NSRange(text.startIndex..., in: text)
        var extractedChords: [Chord] = []
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chordString = String(text[chordRange])
            if let chord = Chord(from: chordString) {
                extractedChords.append(chord)
            }
        }
        
        self.chords = extractedChords
        self.key = detectKey(from: extractedChords)
    }
    
    /// Detects the most likely key based on chord usage
    private func detectKey(from chords: [Chord]) -> String? {
        guard !chords.isEmpty else { return nil }
        
        // Count root note occurrences
        let rootCounts = chords.reduce(into: [String: Int]()) { counts, chord in
            counts[chord.root, default: 0] += 1
        }
        
        // Return most common root as likely key
        return rootCounts.max { $0.value < $1.value }?.key
    }
    
    /// Gets unique chords in the progression
    var uniqueChords: [Chord] {
        return Array(Set(chords))
    }
    
    /// Gets the complexity of the progression
    var complexity: ProgressionComplexity {
        let uniqueCount = uniqueChords.count
        let hasAdvancedChords = uniqueChords.contains { $0.complexity == .advanced }
        
        if hasAdvancedChords || uniqueCount > 8 {
            return .complex
        } else if uniqueCount > 4 {
            return .moderate
        } else {
            return .simple
        }
    }
    
    enum ProgressionComplexity: String, CaseIterable {
        case simple = "Simple"
        case moderate = "Moderate"
        case complex = "Complex"
        
        var description: String {
            switch self {
            case .simple: return "Simple (3-4 unique chords)"
            case .moderate: return "Moderate (5-8 unique chords)"
            case .complex: return "Complex (8+ chords or advanced harmony)"
            }
        }
    }
}
