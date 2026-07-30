import XCTest
@testable import Pro7Chords

final class ChordModelTests: XCTestCase {
    
    // MARK: - Chord Parsing Tests
    func testBasicMajorChordParsing() {
        let chord = Chord(from: "C")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.root, "C")
        XCTAssertEqual(chord?.quality, .major)
        XCTAssertTrue(chord?.extensions.isEmpty ?? false)
        XCTAssertNil(chord?.bassNote)
    }
    
    func testMinorChordParsing() {
        let chord = Chord(from: "Am")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.root, "A")
        XCTAssertEqual(chord?.quality, .minor)
        XCTAssertTrue(chord?.extensions.isEmpty ?? false)
    }
    
    func testSeventhChordParsing() {
        let chord = Chord(from: "C7")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.root, "C")
        XCTAssertEqual(chord?.quality, .dominant7)
        
        let maj7Chord = Chord(from: "Cmaj7")
        XCTAssertNotNil(maj7Chord)
        XCTAssertEqual(maj7Chord?.quality, .major7)
    }
    
    func testSharpAndFlatChords() {
        let sharpChord = Chord(from: "F#")
        XCTAssertNotNil(sharpChord)
        XCTAssertEqual(sharpChord?.root, "F#")
        
        let flatChord = Chord(from: "Bb")
        XCTAssertNotNil(flatChord)
        XCTAssertEqual(flatChord?.root, "Bb")
    }
    
    func testSlashChordParsing() {
        let chord = Chord(from: "C/E")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.root, "C")
        XCTAssertEqual(chord?.bassNote, "E")
        XCTAssertEqual(chord?.description, "C/E")
    }
    
    func testSuspendedChordParsing() {
        let sus2 = Chord(from: "Csus2")
        XCTAssertNotNil(sus2)
        XCTAssertEqual(sus2?.quality, .sus2)
        
        let sus4 = Chord(from: "Dsus4")
        XCTAssertNotNil(sus4)
        XCTAssertEqual(sus4?.quality, .sus4)
    }
    
    func testDiminishedAndAugmentedChords() {
        let dim = Chord(from: "Cdim")
        XCTAssertNotNil(dim)
        XCTAssertEqual(dim?.quality, .diminished)
        
        let aug = Chord(from: "Caug")
        XCTAssertNotNil(aug)
        XCTAssertEqual(aug?.quality, .augmented)
    }
    
    // MARK: - Invalid Chord Tests
    func testInvalidChordFormats() {
        XCTAssertNil(Chord(from: "H")) // Invalid root note
        XCTAssertNil(Chord(from: "C##")) // Double sharp
        XCTAssertNil(Chord(from: "123")) // Numbers only
        XCTAssertNil(Chord(from: "")) // Empty string
        XCTAssertNil(Chord(from: "Cxyz")) // Invalid modifier
    }
    
    // MARK: - Chord Description Tests
    func testChordDescriptions() {
        XCTAssertEqual(Chord(from: "C")?.description, "C")
        XCTAssertEqual(Chord(from: "Am")?.description, "Am")
        XCTAssertEqual(Chord(from: "C7")?.description, "C7")
        XCTAssertEqual(Chord(from: "C/E")?.description, "C/E")
        XCTAssertEqual(Chord(from: "Fmaj7")?.description, "Fmaj7")
    }
    
    // MARK: - Chord Equality Tests
    func testChordEquality() {
        let chord1 = Chord(from: "C")
        let chord2 = Chord(from: "C")
        let chord3 = Chord(from: "D")
        
        XCTAssertEqual(chord1, chord2)
        XCTAssertNotEqual(chord1, chord3)
    }
    
    // MARK: - ChordPosition Tests
    func testChordPositionCreation() {
        let position = ChordPosition(chord: "C", slideId: "test-slide", position: 10)
        
        XCTAssertEqual(position.chord, "C")
        XCTAssertEqual(position.slideId, "test-slide")
        XCTAssertEqual(position.position, 10)
        XCTAssertNotNil(position.id)
        XCTAssertNotNil(position.timestamp)
    }
    
    // MARK: - RecentFile Tests
    func testRecentFileCreation() {
        let url = URL(fileURLWithPath: "/tmp/test.pro")
        let recentFile = RecentFile(url: url)
        
        XCTAssertEqual(recentFile.url, url)
        XCTAssertEqual(recentFile.title, "test")
        XCTAssertNotNil(recentFile.id)
        XCTAssertNotNil(recentFile.lastOpened)
    }
}
