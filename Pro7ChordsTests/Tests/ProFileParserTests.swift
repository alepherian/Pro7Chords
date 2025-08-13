import XCTest
@testable import Pro7Chords

final class ProFileParserTests: XCTestCase {
    var parser: ProFileParser!
    
    override func setUp() {
        super.setUp()
        parser = ProFileParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    func testProFileErrorDescriptions() {
        let errors: [ProFileParser.ProFileError] = [
            .invalidFormat("test"),
            .missingRootNode,
            .missingTextElement,
            .corruptedData,
            .unsupportedVersion,
            .fileNotFound,
            .writePermissionDenied
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testFileNotFoundError() async {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent.pro")
        
        do {
            _ = try await parser.addChords(to: nonExistentURL, chords: [:])
            XCTFail("Should have thrown fileNotFound error")
        } catch let error as ProFileParser.ProFileError {
            XCTAssertEqual(error, .fileNotFound)
        } catch {
            XCTFail("Wrong error type thrown: \(error)")
        }
    }
    
    // MARK: - Chord Extraction Tests
    func testExtractChordsFromText() {
        let text = "[C]Amazing [F]grace [G]how [Am]sweet the sound"
        let chords = parser.extractChords(from: text)
        
        XCTAssertEqual(chords.count, 4)
        XCTAssertEqual(chords, ["C", "F", "G", "Am"])
    }
    
    func testExtractChordsWithComplexChords() {
        let text = "[Cmaj7]Test [F#m7b5]complex [Bb/D]chords"
        let chords = parser.extractChords(from: text)
        
        XCTAssertEqual(chords.count, 3)
        XCTAssertEqual(chords, ["Cmaj7", "F#m7b5", "Bb/D"])
    }
    
    func testExtractChordsFromTextWithoutChords() {
        let text = "Amazing grace how sweet the sound"
        let chords = parser.extractChords(from: text)
        
        XCTAssertTrue(chords.isEmpty)
    }
    
    func testExtractChordsWithMalformedBrackets() {
        let text = "[C]Good [Fbroken chord [G]working"
        let chords = parser.extractChords(from: text)
        
        XCTAssertEqual(chords.count, 2)
        XCTAssertEqual(chords, ["C", "G"])
    }
    
    // MARK: - SlideInfo Tests
    func testSlideInfoPreviewText() {
        let longText = "This is a very long line of text that should be truncated at some point for the preview"
        let slideInfo = SlideInfo(id: "test", text: longText, hasChords: false)
        
        XCTAssertTrue(slideInfo.previewText.count <= 50)
        XCTAssertTrue(slideInfo.previewText.hasPrefix("This is a very long line"))
    }
    
    func testSlideInfoWithMultipleLines() {
        let multiLineText = "First line\nSecond line\nThird line"
        let slideInfo = SlideInfo(id: "test", text: multiLineText, hasChords: true)
        
        XCTAssertEqual(slideInfo.previewText, "First line")
        XCTAssertTrue(slideInfo.hasChords)
    }
    
    // MARK: - ProPresenterFileInfo Tests
    func testProPresenterFileInfoCreation() {
        let slides = [
            SlideInfo(id: "1", text: "First slide", hasChords: true),
            SlideInfo(id: "2", text: "Second slide", hasChords: false)
        ]
        
        let fileInfo = ProPresenterFileInfo(
            filename: "test.pro",
            slideCount: 2,
            hasExistingChords: true,
            textSlides: slides
        )
        
        XCTAssertEqual(fileInfo.filename, "test.pro")
        XCTAssertEqual(fileInfo.slideCount, 2)
        XCTAssertTrue(fileInfo.hasExistingChords)
        XCTAssertEqual(fileInfo.textSlides.count, 2)
    }
}
