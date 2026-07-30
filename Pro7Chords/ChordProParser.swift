import Foundation

// MARK: - ChordPro Parser
/// Parses ChordPro format text and separates lyrics from chord information
struct ChordProParser {
    
    // MARK: - Data Structures
    struct ChordPosition {
        let chord: String
        let position: Int
        let length: Int // Length of chord in characters for spacing
    }
    
    struct ParsedChordPro {
        let cleanLyrics: String
        let chordPositions: [ChordPosition]
        let originalText: String
    }
    
    // MARK: - Parsing Methods
    
    /// Parses ChordPro format text into clean lyrics and chord position data
    /// - Parameter chordProText: Text in ChordPro format (e.g., "[C]Amazing [F]grace")
    /// - Returns: ParsedChordPro containing separated lyrics and chord data
    static func parse(_ chordProText: String) -> ParsedChordPro {
        guard !chordProText.isEmpty else {
            return ParsedChordPro(cleanLyrics: "", chordPositions: [], originalText: chordProText)
        }
        
        var cleanLyrics = ""
        var chordPositions: [ChordPosition] = []
        var currentCleanPosition = 0
        
        // Process the text character by character
        var i = chordProText.startIndex
        while i < chordProText.endIndex {
            if chordProText[i] == "[" {
                // Look for the closing bracket
                var j = chordProText.index(after: i)
                while j < chordProText.endIndex && chordProText[j] != "]" {
                    j = chordProText.index(after: j)
                }
                
                if j < chordProText.endIndex {
                    // Found a complete chord bracket
                    let chordStartIndex = chordProText.index(after: i)
                    let chord = String(chordProText[chordStartIndex..<j])
                    
                    // Record the chord at the current position in clean lyrics
                    chordPositions.append(ChordPosition(
                        chord: chord,
                        position: currentCleanPosition,
                        length: chord.count
                    ))
                    
                    // Move past the chord bracket in the original text
                    i = chordProText.index(after: j)
                } else {
                    // No closing bracket found, treat [ as regular text
                    cleanLyrics.append(chordProText[i])
                    currentCleanPosition += 1
                    i = chordProText.index(after: i)
                }
            } else {
                // Regular character - add to clean lyrics
                cleanLyrics.append(chordProText[i])
                currentCleanPosition += 1
                i = chordProText.index(after: i)
            }
        }
        
        return ParsedChordPro(
            cleanLyrics: cleanLyrics,
            chordPositions: chordPositions,
            originalText: chordProText
        )
    }
    
    /// Creates a chord chart representation for ProPresenter's chord system
    /// - Parameter chordPositions: Array of chord positions from parsed ChordPro
    /// - Returns: Chord chart data suitable for ProPresenter's chord_chart field
    static func createChordChart(from chordPositions: [ChordPosition]) -> Data {
        // Create a simple chord chart representation
        // This could be enhanced to match ProPresenter's specific format
        var chordChart = ""
        
        for (index, chord) in chordPositions.enumerated() {
            chordChart += "\(chord.position):\(chord.chord)"
            if index < chordPositions.count - 1 {
                chordChart += ","
            }
        }
        
        return chordChart.data(using: .utf8) ?? Data()
    }
    
    /// Extracts existing chords from text that may already contain ChordPro format
    /// - Parameter text: Text that might contain chord brackets
    /// - Returns: Array of chord names found in the text
    static func extractChords(from text: String) -> [String] {
        let chordPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        var chords: [String] = []
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chord = String(text[chordRange])
            chords.append(chord)
        }
        
        return chords
    }
    
    /// Converts standard chord progressions to ChordPro format
    /// - Parameters:
    ///   - lyrics: Clean lyrics text
    ///   - chords: Array of chords to place
    /// - Returns: ChordPro formatted text
    static func createChordPro(lyrics: String, chords: [String]) -> String {
        guard !chords.isEmpty else { return lyrics }
        
        // Simple algorithm: place chords at word boundaries
        let words = lyrics.split(separator: " ")
        var result = ""
        
        for (index, word) in words.enumerated() {
            if index < chords.count {
                result += "[\(chords[index])]"
            }
            result += word
            if index < words.count - 1 {
                result += " "
            }
        }
        
        return result
    }
    
    /// Validates if text is in ChordPro format
    /// - Parameter text: Text to validate
    /// - Returns: True if text contains chord brackets
    static func isChordPro(_ text: String) -> Bool {
        return text.contains("[") && text.contains("]")
    }
    
    /// Removes all chord brackets from ChordPro text to get clean lyrics
    /// - Parameter chordProText: Text in ChordPro format
    /// - Returns: Clean lyrics without chord brackets
    static func removeChords(from chordProText: String) -> String {
        let chordPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            return chordProText
        }
        
        let range = NSRange(chordProText.startIndex..., in: chordProText)
        return regex.stringByReplacingMatches(
            in: chordProText,
            range: range,
            withTemplate: ""
        )
    }
}

// MARK: - Debug and Utility Extensions
extension ChordProParser.ParsedChordPro: CustomStringConvertible {
    var description: String {
        let chordList = chordPositions.map { "\($0.chord)@\($0.position)" }.joined(separator: ", ")
        return "Lyrics: '\(cleanLyrics)'\nChords: [\(chordList)]"
    }
}

extension ChordProParser.ChordPosition: CustomStringConvertible {
    var description: String {
        return "\(chord)@\(position)"
    }
}
