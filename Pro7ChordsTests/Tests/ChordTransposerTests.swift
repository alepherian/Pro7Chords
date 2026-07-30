import XCTest
@testable import Pro7Chords

final class ChordTransposerTests: XCTestCase {
    var transposer: ChordTransposerService!
    
    override func setUp() {
        super.setUp()
        transposer = ChordTransposerService()
    }
    
    override func tearDown() {
        transposer = nil
        super.tearDown()
    }
    
    // MARK: - Basic Transposition Tests
    func testBasicMajorChordTransposition() {
        XCTAssertEqual(transposer.transpose("C", by: 2), "D")
        XCTAssertEqual(transposer.transpose("G", by: 5), "C")
        XCTAssertEqual(transposer.transpose("B", by: 1), "C")
    }
    
    func testMinorChordTransposition() {
        XCTAssertEqual(transposer.transpose("Am", by: 2), "Bm")
        XCTAssertEqual(transposer.transpose("Cm", by: -1), "Bm")
        XCTAssertEqual(transposer.transpose("Em", by: 7), "Bm")
    }
    
    func testSeventhChordTransposition() {
        XCTAssertEqual(transposer.transpose("C7", by: 2), "D7")
        XCTAssertEqual(transposer.transpose("Cmaj7", by: 5), "Fmaj7")
        XCTAssertEqual(transposer.transpose("Dm7", by: -2), "Cm7")
    }
    
    func testSlashChordTransposition() {
        XCTAssertEqual(transposer.transpose("C/E", by: 2), "D/F#")
        XCTAssertEqual(transposer.transpose("G/B", by: -1), "F#/A#")
        XCTAssertEqual(transposer.transpose("Am/C", by: 3), "Cm/Eb")
    }
    
    func testComplexChordTransposition() {
        XCTAssertEqual(transposer.transpose("Csus4", by: 2), "Dsus4")
        XCTAssertEqual(transposer.transpose("Dadd9", by: -2), "Cadd9")
        XCTAssertEqual(transposer.transpose("F#dim", by: 6), "Cdim")
    }
    
    // MARK: - Text Transposition Tests
    func testTextWithChords() {
        let input = "[C]Amazing grace [F]how sweet the [G]sound"
        let expected = "[D]Amazing grace [G]how sweet the [A]sound"
        XCTAssertEqual(transposer.transposeText(input, by: 2), expected)
    }
    
    func testTextWithMultipleChords() {
        let input = "[C F G]That saved a [Am]wretch like me"
        let expected = "[D G A]That saved a [Bm]wretch like me"
        XCTAssertEqual(transposer.transposeText(input, by: 2), expected)
    }
    
    func testTextWithoutChords() {
        let input = "Amazing grace how sweet the sound"
        XCTAssertEqual(transposer.transposeText(input, by: 2), input)
    }
    
    // MARK: - Edge Cases
    func testNegativeTransposition() {
        XCTAssertEqual(transposer.transpose("C", by: -1), "B")
        XCTAssertEqual(transposer.transpose("C", by: -13), "B") // Full octave + 1
    }
    
    func testLargeTransposition() {
        XCTAssertEqual(transposer.transpose("C", by: 12), "C") // Full octave
        XCTAssertEqual(transposer.transpose("C", by: 25), "C#") // 2 octaves + 1
    }
    
    func testZeroTransposition() {
        XCTAssertEqual(transposer.transpose("C", by: 0), "C")
        XCTAssertEqual(transposer.transpose("F#m7", by: 0), "F#m7")
    }
    
    // MARK: - Key Detection Tests
    func testKeyDetectionFromSimpleProgression() {
        let text = "[C]Amazing [F]grace [G]how [C]sweet"
        XCTAssertEqual(transposer.detectKey(from: text), "C")
    }
    
    func testKeyDetectionFromMinorProgression() {
        let text = "[Am]House of the [F]rising [C]sun [G]down in New [Am]Orleans"
        XCTAssertEqual(transposer.detectKey(from: text), "Am")
    }
    
    func testKeyDetectionWithNoChords() {
        let text = "Amazing grace how sweet the sound"
        XCTAssertNil(transposer.detectKey(from: text))
    }
    
    // MARK: - Chord Suggestions Tests
    func testChordSuggestionsForMajorKey() {
        let suggestions = transposer.getSuggestedChords(for: "C")
        XCTAssertTrue(suggestions.contains("C"))
        XCTAssertTrue(suggestions.contains("F"))
        XCTAssertTrue(suggestions.contains("G"))
    }
    
    func testChordSuggestionsForSharpKey() {
        let suggestions = transposer.getSuggestedChords(for: "F#")
        XCTAssertTrue(suggestions.contains("F#"))
        XCTAssertTrue(suggestions.contains("B"))
        XCTAssertTrue(suggestions.contains("C#"))
    }
    
    // MARK: - Performance Tests
    func testTranspositionPerformance() {
        let longText = String(repeating: "[C]Test [F]lyrics [G]here [Am]again ", count: 1000)
        
        measure {
            _ = transposer.transposeText(longText, by: 2)
        }
    }
}
