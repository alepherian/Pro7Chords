import XCTest
@testable import Pro7Chords

final class Pro7ChordsTests: XCTestCase {
    
    // MARK: - Integration Tests
    func testChordTranspositionIntegration() {
        let transposer = ChordTransposerService()
        let text = "[C]Amazing [F]grace [G]how [Am]sweet"
        
        let transposed = transposer.transposeText(text, by: 2)
        let expectedChords = ["D", "G", "A", "Bm"]
        
        let parser = ProFileParser()
        let extractedChords = parser.extractChords(from: transposed)
        
        XCTAssertEqual(extractedChords, expectedChords)
    }
    
    func testKeyDetectionWithTransposition() {
        let transposer = ChordTransposerService()
        let originalText = "[C]Test [F]song [G]here [C]again"
        
        // Detect original key
        let originalKey = transposer.detectKey(from: originalText)
        XCTAssertEqual(originalKey, "C")
        
        // Transpose and detect new key
        let transposedText = transposer.transposeText(originalText, by: 2)
        let newKey = transposer.detectKey(from: transposedText)
        XCTAssertEqual(newKey, "D")
    }
    
    func testChordModelWithTransposer() {
        let transposer = ChordTransposerService()
        
        // Test complex chord transposition
        let complexChord = "Cmaj7/E"
        let transposed = transposer.transpose(complexChord, by: 2)
        
        // Verify both chords are valid
        XCTAssertNotNil(Chord(from: complexChord))
        XCTAssertNotNil(Chord(from: transposed))
        XCTAssertEqual(transposed, "Dmaj7/F#")
    }
    
    // MARK: - Error Handling Integration
    func testErrorPropagationChain() {
        // Test that errors propagate correctly through the service chain
        let invalidChordText = "[InvalidChord]Test"
        let parser = ProFileParser()
        let chords = parser.extractChords(from: invalidChordText)
        
        XCTAssertEqual(chords, ["InvalidChord"]) // Should extract but not validate
        XCTAssertNil(Chord(from: "InvalidChord")) // Should fail validation
    }
    
    // MARK: - Performance Tests
    func testLargeTextPerformance() {
        let transposer = ChordTransposerService()
        let baseText = "[C]Test [F]lyrics [G]here [Am]again "
        let largeText = String(repeating: baseText, count: 100)
        
        measure {
            _ = transposer.transposeText(largeText, by: 2)
        }
    }
    
    func testChordExtractionPerformance() {
        let parser = ProFileParser()
        let baseText = "[C]Test [F]lyrics [G]here [Am]again "
        let largeText = String(repeating: baseText, count: 100)
        
        measure {
            _ = parser.extractChords(from: largeText)
        }
    }
    
    // MARK: - Edge Case Integration Tests
    func testEmptyInputHandling() {
        let transposer = ChordTransposerService()
        let parser = ProFileParser()
        
        // Test empty string handling
        XCTAssertEqual(transposer.transposeText("", by: 2), "")
        XCTAssertTrue(parser.extractChords(from: "").isEmpty)
        XCTAssertNil(transposer.detectKey(from: ""))
    }
    
    func testSpecialCharacterHandling() {
        let text = "[C]Test with émojis 🎵 and [F]special chars"
        let transposer = ChordTransposerService()
        let parser = ProFileParser()
        
        let chords = parser.extractChords(from: text)
        XCTAssertEqual(chords, ["C", "F"])
        
        let transposed = transposer.transposeText(text, by: 2)
        XCTAssertTrue(transposed.contains("[D]"))
        XCTAssertTrue(transposed.contains("[G]"))
        XCTAssertTrue(transposed.contains("🎵"))
    }
}
