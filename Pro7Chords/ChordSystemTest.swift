import Foundation

// MARK: - Quick Test for ChordPro Functionality
class ChordSystemTest {
    
    static func runQuickTest() {
        print("🧪 Running ChordPro Parser Test")
        print("=" * 40)
        
        let testInputs = [
            "[C]Amazing [F]grace",
            "[G]How sweet the [C]sound",
            "[Am]That saved a [F]wretch like [C]me"
        ]
        
        for (index, input) in testInputs.enumerated() {
            print("\n📝 Test \(index + 1):")
            print("   Input: '\(input)'")
            
            let parsed = ChordProParser.parse(input)
            print("   Clean Lyrics: '\(parsed.cleanLyrics)'")
            print("   Chords: \(parsed.chordPositions.map { "\($0.chord)@\($0.position)" })")
            
            // Verify the parsing worked correctly
            let hasCorrectChords = !parsed.chordPositions.isEmpty
            let hasCleanLyrics = !parsed.cleanLyrics.contains("[") && !parsed.cleanLyrics.contains("]")
            
            if hasCorrectChords && hasCleanLyrics {
                print("   ✅ Parse successful")
            } else {
                print("   ❌ Parse failed - chords: \(hasCorrectChords), clean: \(hasCleanLyrics)")
            }
        }
        
        print("\n" + "=" * 40)
        print("ChordPro parser test complete!")
    }
    
    static func testFileOperations() {
        print("\n🗂️ Testing File Operations")
        print("=" * 40)
        
        // This would test the actual file operations
        // but requires a real ProPresenter file
        print("To test file operations:")
        print("1. Load a ProPresenter file in the app")
        print("2. Add some chords like '[C]Amazing [F]grace'")
        print("3. Save the file")
        print("4. Check the console output for debug information")
        print("5. Re-open the saved file to verify chords are preserved")
    }
}
