import XCTest
@testable import Pro7Chords

class ChordProParserTests: XCTestCase {
    
    func testBasicChordProParsing() {
        let chordProText = "[C]Amazing [F]grace how [G]sweet the [C]sound"
        let parsed = ChordProParser.parse(chordProText)
        
        XCTAssertEqual(parsed.cleanLyrics, "Amazing grace how sweet the sound")
        XCTAssertEqual(parsed.chordPositions.count, 4)
        
        XCTAssertEqual(parsed.chordPositions[0].chord, "C")
        XCTAssertEqual(parsed.chordPositions[0].position, 0)
        
        XCTAssertEqual(parsed.chordPositions[1].chord, "F")
        XCTAssertEqual(parsed.chordPositions[1].position, 8)
        
        XCTAssertEqual(parsed.chordPositions[2].chord, "G")
        XCTAssertEqual(parsed.chordPositions[2].position, 17)
        
        XCTAssertEqual(parsed.chordPositions[3].chord, "C")
        XCTAssertEqual(parsed.chordPositions[3].position, 27)
    }
    
    func testEmptyInput() {
        let parsed = ChordProParser.parse("")
        XCTAssertEqual(parsed.cleanLyrics, "")
        XCTAssertEqual(parsed.chordPositions.count, 0)
    }
    
    func testNoChords() {
        let text = "Amazing grace how sweet the sound"
        let parsed = ChordProParser.parse(text)
        XCTAssertEqual(parsed.cleanLyrics, text)
        XCTAssertEqual(parsed.chordPositions.count, 0)
    }
    
    func testComplexChords() {
        let chordProText = "[Am7]I searched the [G/B]world but [C]it couldn't [Dm/F]fill me"
        let parsed = ChordProParser.parse(chordProText)
        
        XCTAssertEqual(parsed.cleanLyrics, "I searched the world but it couldn't fill me")
        XCTAssertEqual(parsed.chordPositions.count, 4)
        
        XCTAssertEqual(parsed.chordPositions[0].chord, "Am7")
        XCTAssertEqual(parsed.chordPositions[1].chord, "G/B")
        XCTAssertEqual(parsed.chordPositions[2].chord, "C")
        XCTAssertEqual(parsed.chordPositions[3].chord, "Dm/F")
    }
    
    func testExtractChords() {
        let text = "[C]Amazing [F]grace [G]how [Am]sweet"
        let chords = ChordProParser.extractChords(from: text)
        
        XCTAssertEqual(chords.count, 4)
        XCTAssertEqual(chords[0], "C")
        XCTAssertEqual(chords[1], "F")
        XCTAssertEqual(chords[2], "G")
        XCTAssertEqual(chords[3], "Am")
    }
    
    func testRemoveChords() {
        let chordProText = "[C]Amazing [F]grace how [G]sweet the [C]sound"
        let cleanText = ChordProParser.removeChords(from: chordProText)
        
        XCTAssertEqual(cleanText, "Amazing grace how sweet the sound")
    }
    
    func testIsChordPro() {
        XCTAssertTrue(ChordProParser.isChordPro("[C]Amazing grace"))
        XCTAssertFalse(ChordProParser.isChordPro("Amazing grace"))
        XCTAssertFalse(ChordProParser.isChordPro("Amazing (grace)"))
        XCTAssertTrue(ChordProParser.isChordPro("Amazing [F]grace"))
    }
    
    func testCreateChordPro() {
        let lyrics = "Amazing grace how sweet"
        let chords = ["C", "F", "G"]
        let result = ChordProParser.createChordPro(lyrics: lyrics, chords: chords)
        
        XCTAssertEqual(result, "[C]Amazing [F]grace [G]how sweet")
    }
    
    func testChordAtBeginning() {
        let chordProText = "[C]Amazing grace"
        let parsed = ChordProParser.parse(chordProText)
        
        XCTAssertEqual(parsed.cleanLyrics, "Amazing grace")
        XCTAssertEqual(parsed.chordPositions.count, 1)
        XCTAssertEqual(parsed.chordPositions[0].chord, "C")
        XCTAssertEqual(parsed.chordPositions[0].position, 0)
    }
    
    func testChordAtEnd() {
        let chordProText = "Amazing grace [C]"
        let parsed = ChordProParser.parse(chordProText)
        
        XCTAssertEqual(parsed.cleanLyrics, "Amazing grace ")
        XCTAssertEqual(parsed.chordPositions.count, 1)
        XCTAssertEqual(parsed.chordPositions[0].chord, "C")
        XCTAssertEqual(parsed.chordPositions[0].position, 14)
    }
    
    func testMultipleLines() {
        let chordProText = "[C]Amazing grace\n[F]How sweet the [G]sound"
        let parsed = ChordProParser.parse(chordProText)
        
        XCTAssertEqual(parsed.cleanLyrics, "Amazing grace\nHow sweet the sound")
        XCTAssertEqual(parsed.chordPositions.count, 3)
        
        XCTAssertEqual(parsed.chordPositions[0].chord, "C")
        XCTAssertEqual(parsed.chordPositions[0].position, 0)
        
        XCTAssertEqual(parsed.chordPositions[1].chord, "F")
        XCTAssertEqual(parsed.chordPositions[1].position, 14)
        
        XCTAssertEqual(parsed.chordPositions[2].chord, "G")
        XCTAssertEqual(parsed.chordPositions[2].position, 28)
    }
}
