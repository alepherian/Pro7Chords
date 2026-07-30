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
    
    // MARK: - NEW: Freedom File Comparison Test
    func testCompareFreedomFiles() async {
        print("🔍 === RUNNING FREEDOM FILE COMPARISON ===")
        
        let testFilesURL = URL(fileURLWithPath: "/Users/atomusic/Documents/Pro7Chords/Pro7Chords/TestFiles")
        let freedomEURL = testFilesURL.appendingPathComponent("Freedom (E).pro")
        let freedomGURL = testFilesURL.appendingPathComponent("Freedom (G).pro")
        
        // Check if files exist
        guard FileManager.default.fileExists(atPath: freedomEURL.path) else {
            XCTFail("Freedom (E).pro not found at expected location")
            return
        }
        
        guard FileManager.default.fileExists(atPath: freedomGURL.path) else {
            XCTFail("Freedom (G).pro not found at expected location")
            return
        }
        
        do {
            // Analyze both files
            print("\n📊 ANALYZING Freedom (G).pro (WORKING VERSION):")
            let analysisG = try await detailedFileAnalysis(freedomGURL, fileLabel: "Freedom (G)")
            
            print("\n📊 ANALYZING Freedom (E).pro (NON-WORKING VERSION):")
            let analysisE = try await detailedFileAnalysis(freedomEURL, fileLabel: "Freedom (E)")
            
            // Compare the results
            print("\n🔍 === COMPARISON RESULTS ===")
            print("Freedom (G) slides with chords: \(analysisG.slidesWithChords)")
            print("Freedom (E) slides with chords: \(analysisE.slidesWithChords)")
            
            if analysisG.slidesWithChords.count != analysisE.slidesWithChords.count {
                print("❌ DIFFERENT NUMBER OF SLIDES WITH CHORDS DETECTED!")
                print("   This suggests the chord detection is failing in Freedom (E)")
            }
            
            // Compare specific slides
            for (index, (slideG, slideE)) in zip(analysisG.slideDetails, analysisE.slideDetails).enumerated() {
                if slideG.hasChords != slideE.hasChords {
                    print("❌ SLIDE \(index + 1) DIFFERENCE:")
                    print("   Freedom (G): hasChords=\(slideG.hasChords), chordCount=\(slideG.chordCount)")
                    print("   Freedom (E): hasChords=\(slideE.hasChords), chordCount=\(slideE.chordCount)")
                    print("   Group: \(slideG.groupName)")
                    print("   Text: \(slideG.cleanText.prefix(50))...")
                    
                    // Show the actual chord data differences
                    if slideG.hasChords && !slideE.hasChords {
                        print("   🎵 MISSING CHORDS IN FREEDOM (E):")
                        for chord in slideG.chordDetails {
                            print("      - '\(chord.chord)' at position \(chord.startPos)-\(chord.endPos)")
                        }
                    }
                    
                    // This is likely the Intro/Interlude slide
                    if slideG.groupName.lowercased().contains("intro") || slideG.groupName.lowercased().contains("interlude") || slideG.cleanText.count < 20 {
                        print("   ⚠️  This appears to be an instrumental section (Intro/Interlude)")
                        print("   Freedom (G) detects chords here, but Freedom (E) does not")
                    }
                }
            }
            
            // Binary comparison
            print("\n🔍 === BINARY COMPARISON ===")
            let dataE = try Data(contentsOf: freedomEURL)
            let dataG = try Data(contentsOf: freedomGURL)
            
            print("Freedom (E).pro: \(dataE.count) bytes")
            print("Freedom (G).pro: \(dataG.count) bytes")
            print("Size difference: \(abs(dataE.count - dataG.count)) bytes")
            
        } catch {
            XCTFail("Error during analysis: \(error)")
        }
    }
    
    // MARK: - Helper: Detailed File Analysis
    private func detailedFileAnalysis(_ url: URL, fileLabel: String) async throws -> FileAnalysisResult {
        let data = try Data(contentsOf: url)
        let presentation = try RVData_Presentation(serializedBytes: data)
        
        print("   File: \(fileLabel)")
        print("   Size: \(data.count) bytes")
        print("   Presentation name: '\(presentation.name)'")
        
        var slideDetails: [SlideDetailAnalysis] = []
        var slidesWithChords: [Int] = []
        var slideIndex = 0
        
        guard let arrangement = presentation.arrangements.first else {
            throw ProFileParser.ProFileError.invalidFormat("No arrangement found")
        }
        
        for groupID in arrangement.groupIdentifiers {
            let groupUUID = groupID.string
            guard let cueGroup = presentation.cueGroups.first(where: { $0.group.uuid.string == groupUUID }) else {
                continue
            }
            
            print("   📁 Group: '\(cueGroup.group.name)' (UUID: \(groupUUID.prefix(8))...)")
            
            for cueID in cueGroup.cueIdentifiers {
                let cueUUID = cueID.string
                guard let cue = presentation.cues.first(where: { $0.uuid.string == cueUUID }) else {
                    continue
                }
                
                for action in cue.actions {
                    if action.type == .presentationSlide {
                        slideIndex += 1
                        
                        if case .slide(let slideData) = action.actionTypeData {
                            if case .presentation(let presentationSlide) = slideData.slide {
                                let baseSlide = presentationSlide.baseSlide
                                let analysis = detailedSlideAnalysis(baseSlide, slideNumber: slideIndex, groupName: cueGroup.group.name)
                                
                                slideDetails.append(analysis)
                                
                                if analysis.hasChords {
                                    slidesWithChords.append(slideIndex)
                                }
                                
                                print("     Slide \(slideIndex): '\(analysis.cleanText.prefix(30))...' - Chords: \(analysis.hasChords) (\(analysis.chordCount))")
                            }
                        }
                    }
                }
            }
        }
        
        return FileAnalysisResult(
            slideDetails: slideDetails,
            slidesWithChords: slidesWithChords
        )
    }
    
    // MARK: - Helper: Detailed Slide Analysis
    private func detailedSlideAnalysis(_ baseSlide: RVData_Slide, slideNumber: Int, groupName: String) -> SlideDetailAnalysis {
        var allText = ""
        var hasChords = false
        var chordCount = 0
        var chordDetails: [ChordDetail] = []
        
        for (elementIndex, element) in baseSlide.elements.enumerated() {
            let isTextElement = (element.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0
            if isTextElement {
                let graphicsElement = element.element
                if graphicsElement.hasText {
                    let textElement = graphicsElement.text
                    let cleanText = parser.extractCleanTextFromRTF(textElement.rtfData)
                    allText += (allText.isEmpty ? "" : "\n") + cleanText
                    
                    // DETAILED CHORD ANALYSIS
                    if textElement.hasAttributes {
                        let attributes = textElement.attributes
                        print("       Element \(elementIndex): \(attributes.customAttributes.count) custom attributes")
                        
                        for (attrIndex, attr) in attributes.customAttributes.enumerated() {
                            if !attr.chord.isEmpty {
                                hasChords = true
                                chordCount += 1
                                let chordDetail = ChordDetail(
                                    chord: attr.chord,
                                    startPos: Int(attr.range.start),
                                    endPos: Int(attr.range.end),
                                    elementIndex: elementIndex,
                                    attributeIndex: attrIndex
                                )
                                chordDetails.append(chordDetail)
                                
                                print("         Chord \(chordCount): '\(attr.chord)' at position \(attr.range.start)-\(attr.range.end)")
                            }
                        }
                    } else {
                        print("       Element \(elementIndex): No attributes")
                    }
                }
            }
        }
        
        return SlideDetailAnalysis(
            slideNumber: slideNumber,
            groupName: groupName,
            cleanText: allText,
            hasChords: hasChords,
            chordCount: chordCount,
            chordDetails: chordDetails
        )
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

// MARK: - Analysis Result Types
private struct FileAnalysisResult {
    let slideDetails: [SlideDetailAnalysis]
    let slidesWithChords: [Int]
}

private struct SlideDetailAnalysis {
    let slideNumber: Int
    let groupName: String
    let cleanText: String
    let hasChords: Bool
    let chordCount: Int
    let chordDetails: [ChordDetail]
}

private struct ChordDetail {
    let chord: String
    let startPos: Int
    let endPos: Int
    let elementIndex: Int
    let attributeIndex: Int
}

// MARK: - Extension to access private methods
extension ProFileParser {
    func extractCleanTextFromRTF(_ rtfData: Data) -> String {
        do {
            let attributedString = try NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return attributedString.string
        } catch {
            return ""
        }
    }
}