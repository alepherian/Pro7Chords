import Foundation

// MARK: - Demonstration of the New Chord System
/// This file demonstrates how to use the updated ProFileParser with proper chord separation
class ChordSystemDemo {
    
    /// Demonstrates the difference between old and new chord processing
    static func demonstrateChordProcessing() {
        print("🎵 ProPresenter 7 Chord System Demonstration")
        print("=" * 50)
        
        // Example ChordPro input
        let chordProExample = "[C]Amazing [F]grace how [G]sweet the [C]sound"
        
        print("\n1. INPUT (ChordPro format):")
        print("   \(chordProExample)")
        
        // Parse using the new system
        let parsed = ChordProParser.parse(chordProExample)
        
        print("\n2. PARSED RESULTS:")
        print("   Clean Lyrics (for audience): '\(parsed.cleanLyrics)'")
        print("   Chord Positions (for stage display):")
        for chord in parsed.chordPositions {
            print("     - \(chord.chord) at position \(chord.position)")
        }
        
        print("\n3. HOW IT WORKS:")
        print("   ✅ Audience sees: '\(parsed.cleanLyrics)'")
        print("   ✅ Stage display shows: Chords above lyrics")
        print("   ✅ No visible [C] [F] [G] brackets on audience screen")
        
        print("\n4. COMPARISON:")
        print("   ❌ Old way: '[C]Amazing [F]grace...' (chords visible to audience)")
        print("   ✅ New way: 'Amazing grace...' (chords hidden from audience)")
        
        print("\n" + "=" * 50)
        print("Ready to test with your ProPresenter files!")
    }
    
    /// Quick test you can run from anywhere in your app
    static func quickTest() {
        ChordSystemTest.runQuickTest()
    }
    
    /// Shows the internal chord chart data structure
    static func showChordChartStructure() {
        let chordProText = "[Am]When I [F]see the [C]cross I [G]worship"
        let parsed = ChordProParser.parse(chordProText)
        
        // Create chord chart data
        var chordChart: [String: Any] = [:]
        var chords: [[String: Any]] = []
        
        for position in parsed.chordPositions {
            chords.append([
                "chord": position.chord,
                "position": position.position,
                "length": position.length
            ])
        }
        
        chordChart["chords"] = chords
        chordChart["format"] = "chordpro"
        chordChart["version"] = "1.0"
        
        print("\n🎵 Chord Chart Data Structure:")
        print("Input: \(chordProText)")
        print("Clean Lyrics: \(parsed.cleanLyrics)")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: chordChart, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Chord Chart JSON:")
            print(jsonString)
        }
    }
}

// MARK: - Helper Extensions
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Usage Instructions
/*
 USAGE INSTRUCTIONS:
 
 1. To see the demonstration:
    ChordSystemDemo.demonstrateChordProcessing()
 
 2. To see chord chart structure:
    ChordSystemDemo.showChordChartStructure()
 
 3. To use with your ProPresenter files:
    let parser = ProFileParser()
    let chords = ["0": "[C]Amazing [F]grace", "1": "[G]How sweet the [C]sound"]
    let outputURL = try await parser.addChords(to: inputURL, chords: chords)
 
 KEY CHANGES:
 
 ✅ Chords are now stored in ProPresenter's chord_chart field
 ✅ Clean lyrics (without brackets) go in text RTF data
 ✅ Stage displays can show chords above lyrics
 ✅ Audience displays show only clean lyrics
 ✅ No more visible [C] [F] [G] brackets on audience screens
 
 BEFORE (Old System):
 - Text RTF: "[C]Amazing [F]grace"
 - Audience sees: "[C]Amazing [F]grace" ❌
 - Stage sees: "[C]Amazing [F]grace" ❌
 
 AFTER (New System):
 - Text RTF: "Amazing grace"
 - Chord Chart: JSON with chord positions
 - Audience sees: "Amazing grace" ✅
 - Stage sees: Chords above "Amazing grace" ✅
 
 */
