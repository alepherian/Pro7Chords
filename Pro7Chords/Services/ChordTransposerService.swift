import Foundation
import SwiftUI

// MARK: - Chord Transposer Service
@MainActor
class ChordTransposerService: ObservableObject {
    @Published var currentKey: String = "C"
    @Published var transposeSteps: Int = 0
    
    private let chromaticScale = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let flatEquivalents = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    
    // MARK: - Transposition
    func transpose(_ chord: String, by steps: Int) -> String {
        // Handle multiple chords separated by spaces
        let chords = chord.split(separator: " ")
        let transposedChords = chords.map { transposeIndividualChord(String($0), by: steps) }
        return transposedChords.joined(separator: " ")
    }
    
    func transposeText(_ text: String, by steps: Int) -> String {
        let chordPattern = #"\[([^\]]+)\]"#
        
        return StringUtilities.replacingOccurrences(
            in: text,
            pattern: chordPattern,
            with: { matchedText in
                // The matchedText includes the brackets [chord]
                // Extract the chord text without brackets
                let startIndex = matchedText.index(matchedText.startIndex, offsetBy: 1)
                let endIndex = matchedText.index(matchedText.endIndex, offsetBy: -1)
                
                if startIndex < endIndex {
                    let chordText = String(matchedText[startIndex..<endIndex])
                    let transposedChord = transpose(chordText, by: steps)
                    return "[\(transposedChord)]"
                }
                
                // Fallback: return original match if extraction fails
                return matchedText
            }
        )
    }
    
    private func transposeIndividualChord(_ chord: String, by steps: Int) -> String {
        // Handle slash chords (e.g., C/E)
        let components = chord.split(separator: "/")
        let mainChord = String(components[0])
        let bassNote = components.count > 1 ? String(components[1]) : nil
        
        // Transpose main chord
        let transposedMain = transposeRootNote(mainChord, by: steps)
        
        // Transpose bass note if present
        if let bass = bassNote {
            let transposedBass = transposeRootNote(bass, by: steps)
            return "\(transposedMain)/\(transposedBass)"
        }
        
        return transposedMain
    }
    
    private func transposeRootNote(_ chord: String, by steps: Int) -> String {
        // Extract root note (first 1-2 characters)
        let rootPattern = #"^[A-G][#b]?"#
        guard let rootRange = chord.range(of: rootPattern, options: .regularExpression) else {
            return chord // Return unchanged if no valid root found
        }
        
        let rootNote = String(chord[rootRange])
        let modifier = String(chord[rootRange.upperBound...])
        
        // Handle flat notation
        let normalizedRoot = normalizeRootNote(rootNote)
        
        guard let currentIndex = chromaticScale.firstIndex(of: normalizedRoot) else {
            return chord // Return unchanged if root not found
        }
        
        // Calculate new index (handle negative steps and wrapping)
        let newIndex = (currentIndex + steps + chromaticScale.count * 100) % chromaticScale.count
        let newRoot = chromaticScale[newIndex]
        
        // Preserve flat notation preference where appropriate
        let finalRoot = shouldUseFlat(newRoot, originalWasFlat: rootNote.contains("b")) ?
                       flatEquivalents[newIndex] : newRoot
        
        return finalRoot + modifier
    }
    
    private func normalizeRootNote(_ note: String) -> String {
        switch note {
        case "Db": return "C#"
        case "Eb": return "D#"
        case "Gb": return "F#"
        case "Ab": return "G#"
        case "Bb": return "A#"
        default: return note
        }
    }
    
    private func shouldUseFlat(_ note: String, originalWasFlat: Bool) -> Bool {
        // Prefer flats in flat keys and when original used flats
        let flatKeys = ["F", "Bb", "Eb", "Ab", "Db", "Gb"]
        return originalWasFlat || flatKeys.contains(currentKey)
    }
    
    // MARK: - Key Detection
    static func detectKey(from text: String) -> String? {
        let chordPattern = #"\[([A-G][#b]?[^/\]]*)\]"#
        let regex = try? NSRegularExpression(pattern: chordPattern)
        let range = NSRange(text.startIndex..., in: text)
        
        var chordCounts: [String: Int] = [:]
        
        regex?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chordText = String(text[chordRange])
            if let chord = Chord(from: chordText) {
                chordCounts[chord.root, default: 0] += 1
            }
        }
        
        // Return most common chord as likely key
        return chordCounts.max { $0.value < $1.value }?.key
    }
    
    func detectKey(from text: String) -> String? {
        return ChordTransposerService.detectKey(from: text)
    }
    
    // MARK: - Chord Suggestions
    func getSuggestedChords(for key: String) -> [String] {
        guard let keyIndex = chromaticScale.firstIndex(of: key) else {
            return ["C", "F", "G", "Am"] // Default progression
        }
        
        // Common chord progressions in the key
        let majorKeyChords = [
            chromaticScale[keyIndex], // I
            chromaticScale[(keyIndex + 5) % 12], // V
            chromaticScale[(keyIndex + 9) % 12] + "m", // vi
            chromaticScale[(keyIndex + 5) % 12], // IV (same as V but as major)
        ]
        
        return majorKeyChords
    }
    
    // MARK: - Chord Analysis
    func analyzeChordProgression(_ text: String) -> ChordProgressionAnalysis {
        let chords = extractChordsFromText(text)
        let uniqueChords = Array(Set(chords))
        
        var analysis = ChordProgressionAnalysis()
        analysis.totalChords = chords.count
        analysis.uniqueChords = uniqueChords.count
        analysis.mostCommonChord = findMostCommonChord(chords)
        analysis.suggestedKey = detectKey(from: text)
        
        return analysis
    }
    
    private func extractChordsFromText(_ text: String) -> [String] {
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
    
    private func findMostCommonChord(_ chords: [String]) -> String? {
        let chordCounts = chords.reduce(into: [String: Int]()) { counts, chord in
            counts[chord, default: 0] += 1
        }
        
        return chordCounts.max { $0.value < $1.value }?.key
    }
}

// MARK: - Chord Progression Analysis
struct ChordProgressionAnalysis {
    var totalChords: Int = 0
    var uniqueChords: Int = 0
    var mostCommonChord: String?
    var suggestedKey: String?
    var complexity: ProgressionComplexity = .simple
    
    enum ProgressionComplexity {
        case simple, moderate, complex
        
        var description: String {
            switch self {
            case .simple: return "Simple (3-4 unique chords)"
            case .moderate: return "Moderate (5-7 unique chords)"
            case .complex: return "Complex (8+ unique chords)"
            }
        }
    }
    
    mutating func calculateComplexity() {
        switch uniqueChords {
        case 0...4: complexity = .simple
        case 5...7: complexity = .moderate
        default: complexity = .complex
        }
    }
}
