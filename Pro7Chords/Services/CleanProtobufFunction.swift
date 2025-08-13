import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#endif
import SwiftProtobuf

func handleProtobufProPresenterFile(data: Data) async throws -> String {
    print("🔬 Attempting correct ProPresenter 7 protobuf parsing...")
    
    do {
        // Parse as Presentation (not PlaylistDocument!)
        let presentation = try RVData_Presentation(serializedBytes: data)
        print("✅ Successfully parsed as Presentation!")
        print("Presentation name: \(presentation.name)")
        print("Found \(presentation.cues.count) cues")
        
        // 🔍 DEEP DIVE: Investigate arrangement data
        print("\n🔍 === PROTOBUF INVESTIGATION ===")
        investigateArrangementData(presentation)
        investigateSlideGroups(presentation)
        investigateCueStructure(presentation)
        print("🔍 === END INVESTIGATION ===\n")
        
        // Check if there's arrangement data that defines slide order
        if !presentation.arrangements.isEmpty {
            print("🎵 Found arrangement data - using arrangement order")
            return try await extractLyricsFromArrangement(presentation)
        } else {
            print("⚠️ No arrangement found - using cue order (may not match ProPresenter display order)")
            return try await extractLyricsFromCues(presentation)
        }
        
    } catch let error as SwiftProtobuf.BinaryDecodingError {
        print("❌ Protobuf decoding failed: \(error)")
        print("Error code: \(error.localizedDescription)")
        
        throw FileManagerError.invalidProPresenterFormat(
            """
            ProPresenter protobuf schema mismatch.
            
            Your ProPresenter version uses a different internal format than expected.
            
            Debug info:
            • File size: \(data.count) bytes
            • Protobuf signature: \(data.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " "))
            • Error: \(error.localizedDescription)
            
            The protobuf definitions may need updating for your ProPresenter version.
            """)
    } catch {
        throw FileManagerError.loadFailed("ProPresenter file parsing failed: \(error.localizedDescription)")
    }
}

// MARK: - ProPresenter Arrangement-Based Extraction
func extractLyricsFromArrangement(_ presentation: RVData_Presentation) async throws -> String {
    print("🎵 Extracting lyrics using arrangement order...")
    
    guard let arrangement = presentation.arrangements.first else {
        print("⚠️ No arrangements found, falling back to cue order")
        return try await extractLyricsFromCues(presentation)
    }
    
    print("Using arrangement: '\(arrangement.name)' with \(arrangement.groupIdentifiers.count) groups")
    
    // Create maps for fast lookups
    var cueGroupMap: [String: RVData_Presentation.CueGroup] = [:]
    for cueGroup in presentation.cueGroups {
        if cueGroup.hasGroup {
            cueGroupMap[cueGroup.group.uuid.string] = cueGroup
        }
    }
    
    var cueMap: [String: RVData_Cue] = [:]
    for cue in presentation.cues {
        cueMap[cue.uuid.string] = cue
    }
    
    var allLyrics: [String] = []
    
    // Follow the arrangement order
    for (groupIndex, groupUUID) in arrangement.groupIdentifiers.enumerated() {
        let groupUUIDString = groupUUID.string
        print("Processing arrangement group \(groupIndex + 1): \(groupUUIDString.prefix(8))...")
        
        // Find the cue group that matches this arrangement group
        guard let cueGroup = cueGroupMap[groupUUIDString] else {
            print("  ⚠️ No cue group found for group UUID")
            continue
        }
        
        print("  ✅ Found cue group: '\(cueGroup.group.name)' with \(cueGroup.cueIdentifiers.count) cues")
        
        // Extract text from all cues in this group (in order)
        for (cueIndex, cueUUID) in cueGroup.cueIdentifiers.enumerated() {
            let cueUUIDString = cueUUID.string
            
            guard let cue = cueMap[cueUUIDString] else {
                print("    ⚠️ No cue found for cue UUID \(cueUUIDString.prefix(8))...")
                allLyrics.append("") // Add placeholder
                continue
            }
            
            print("    Processing cue \(cueIndex + 1): \(cueUUIDString.prefix(8))...")
            
            if let slideText = extractTextFromCue(cue, cueIndex: cueIndex) {
                allLyrics.append(slideText)
                print("      📝 Extracted: \(slideText.prefix(30))...")
            } else {
                allLyrics.append("") // Add placeholder for empty slides
                print("      ⚠️ No text found")
            }
        }
    }
    
    print("\n📈 Summary: Extracted \(allLyrics.count) slides using arrangement order")
    print("📈 Non-empty slides: \(allLyrics.filter { !$0.isEmpty }.count)")
    
    if allLyrics.filter({ !$0.isEmpty }).isEmpty {
        throw FileManagerError.invalidProPresenterFormat("No text content found in any slides")
    }
    
    // Combine all slides with clear separators
    let combinedLyrics = allLyrics.joined(separator: "\n\n--- Next Slide ---\n\n")
    print("✅ Successfully extracted \(combinedLyrics.count) characters in correct arrangement order")
    
    return combinedLyrics
}

func extractTextFromCue(_ cue: RVData_Cue, cueIndex: Int) -> String? {
    print("Processing cue \(cueIndex + 1)/total: '\(cue.name)'")
    
    for (actionIndex, action) in cue.actions.enumerated() {
        print("  Checking action \(actionIndex + 1): type = \(action.type)")
        
        // Look for presentation slide actions
        if action.type == .presentationSlide {
            print("  ✅ Found presentation slide action!")
            
            // Get the slide data
            if case .slide(let slideData) = action.actionTypeData {
                if case .presentation(let presentationSlide) = slideData.slide {
                    print("    Processing presentation slide...")
                    
                    let baseSlide = presentationSlide.baseSlide
                    print("    Slide has \(baseSlide.elements.count) elements")
                    
                    var slideText = ""
                    
                    // Extract text from all elements in this slide
                    for (elementIndex, slideElement) in baseSlide.elements.enumerated() {
                        print("    Checking element \(elementIndex + 1): info = \(slideElement.info)")
                        
                        // Check if this is a text element
                        if (slideElement.info & UInt32(RVData_Slide.Element.Info.isTextElement.rawValue)) != 0 {
                            print("    ✅ Found text element!")
                            
                            let graphicsElement = slideElement.element
                            if graphicsElement.hasText {
                                let textData = graphicsElement.text
                                if !textData.rtfData.isEmpty {
                                    print("      RTF data size: \(textData.rtfData.count) bytes")
                                    
                                    // Try RTF parsing first
                                    do {
                                        let attributedString = try NSAttributedString(
                                            data: textData.rtfData,
                                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                                            documentAttributes: nil
                                        )
                                        let text = attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !text.isEmpty {
                                            print("      ✅ Extracted RTF text: \"\(text.prefix(50))...\"")
                                            slideText += text + "\n"
                                        }
                                    } catch {
                                        print("      RTF parsing failed: \(error)")
                                        // Try plain text fallback
                                        if let stringData = String(data: textData.rtfData, encoding: .utf8) {
                                            let text = stringData.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !text.isEmpty {
                                                print("      ✅ Extracted as plain text: \"\(text.prefix(50))...\"")
                                                slideText += text + "\n"
                                            }
                                        }
                                    }
                                } else {
                                    print("      Text element has no RTF data")
                                }
                            } else {
                                print("      Graphics element has no text property")
                            }
                        }
                    }
                    
                    // Return the extracted text
                    let trimmedText = slideText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty {
                        print("    📝 Extracted slide text (\(trimmedText.count) characters)")
                        return trimmedText
                    } else {
                        print("    ⚠️ Slide had no text content")
                        return nil
                    }
                } else {
                    print("    Slide is not a presentation slide (might be prop slide)")
                }
            } else {
                print("    Action doesn't contain slide data")
            }
        }
    }
    
    print("  ⚠️ No presentation slide action found in cue")
    return nil
}

func extractLyricsFromCues(_ presentation: RVData_Presentation) async throws -> String {
    print("📋 Extracting lyrics using cue order (may not match ProPresenter display)...")
    
    var allLyrics: [String] = []
    
    // Extract lyrics from ALL presentation slides IN ORDER
    for (cueIndex, cue) in presentation.cues.enumerated() {
        if let slideText = extractTextFromCue(cue, cueIndex: cueIndex) {
            allLyrics.append(slideText)
        } else {
            // Add empty placeholder to maintain slide order
            allLyrics.append("")
        }
    }
    
    print("📈 Summary: Found \(presentation.cues.count) slides total with \(allLyrics.filter { !$0.isEmpty }.count) containing text")
    
    if allLyrics.filter({ !$0.isEmpty }).isEmpty {
        throw FileManagerError.invalidProPresenterFormat("No text content found in any slides")
    }
    
    // Combine all slides with clear separators, preserving empty slides for correct order
    let combinedLyrics = allLyrics.joined(separator: "\n\n--- Next Slide ---\n\n")
    print("✅ Successfully extracted \(combinedLyrics.count) characters from \(allLyrics.count) slides (\(allLyrics.filter { !$0.isEmpty }.count) with text)")
    
    return combinedLyrics
}

// MARK: - Protobuf Investigation Functions
func investigateArrangementData(_ presentation: RVData_Presentation) {
    print("📁 === ARRANGEMENTS ===")
    print("Number of arrangements: \(presentation.arrangements.count)")
    
    for (index, arrangement) in presentation.arrangements.enumerated() {
        print("\n  Arrangement \(index + 1):")
        print("    Name: '\(arrangement.name)'")
        print("    UUID: \(arrangement.uuid.string)")
        print("    Group identifiers count: \(arrangement.groupIdentifiers.count)")
        
        for (groupIndex, groupID) in arrangement.groupIdentifiers.prefix(10).enumerated() {
            print("        Group \(groupIndex + 1): \(groupID.string.prefix(8))...")
        }
        
        if arrangement.groupIdentifiers.count > 10 {
            print("        ... and \(arrangement.groupIdentifiers.count - 10) more groups")
        }
    }
}

func investigateSlideGroups(_ presentation: RVData_Presentation) {
    print("\n📋 === CUE GROUPS ===")
    print("Number of cue groups: \(presentation.cueGroups.count)")
    
    for (index, cueGroup) in presentation.cueGroups.enumerated() {
        print("\n  Cue Group \(index + 1):")
        if cueGroup.hasGroup {
            print("    Group name: '\(cueGroup.group.name)'")
            print("    Group UUID: \(cueGroup.group.uuid.string)")
        }
        print("    Cue identifiers count: \(cueGroup.cueIdentifiers.count)")
        
        for (cueIndex, cueID) in cueGroup.cueIdentifiers.prefix(5).enumerated() {
            print("      Cue \(cueIndex + 1): \(cueID.string.prefix(8))...")
        }
    }
}

func investigateCueStructure(_ presentation: RVData_Presentation) {
    print("\n🎬 === CUE STRUCTURE ===")
    
    for (index, cue) in presentation.cues.prefix(5).enumerated() {
        print("\n  Cue \(index + 1):")
        print("    Name: '\(cue.name)'")
        print("    UUID: \(cue.uuid.string)")
        print("    Actions count: \(cue.actions.count)")
    }
    
    if presentation.cues.count > 5 {
        print("    ... and \(presentation.cues.count - 5) more cues")
    }
    
    // 🔑 KEY INVESTIGATION: Map arrangement order to cues
    if !presentation.arrangements.isEmpty {
        print("\n🔑 === ARRANGEMENT TO CUE MAPPING ===")
        let arrangement = presentation.arrangements[0]
        print("Using arrangement: '\(arrangement.name)'")
        print("Arrangement has \(arrangement.groupIdentifiers.count) group identifiers")
        
        // Create a map of cue UUIDs to cue indices for quick lookup
        var cueMap: [String: (index: Int, cue: RVData_Cue)] = [:]
        for (index, cue) in presentation.cues.enumerated() {
            cueMap[cue.uuid.string] = (index: index, cue: cue)
        }
        
        print("\nMapping arrangement order to cues:")
        for (arrangementIndex, groupID) in arrangement.groupIdentifiers.enumerated() {
            let groupUUID = groupID.string
            
            if let mappedCue = cueMap[groupUUID] {
                print("  ✅ Arrangement position \(arrangementIndex + 1) → Cue \(mappedCue.index + 1): '\(mappedCue.cue.name)'")
            } else {
                print("  ❌ Arrangement position \(arrangementIndex + 1) → No matching cue for \(groupUUID.prefix(8))...")
            }
        }
    }
}
