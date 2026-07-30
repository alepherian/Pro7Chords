import Foundation
import SwiftUI
import SwiftProtobuf

extension FileManager {
    func fileSize(url: URL) -> String? {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
        }
        return nil
    }
}

// MARK: - Recent File Model
struct RecentFile: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let accessedDate: Date
    let lastOpened: Date  // For compatibility with existing code
    let displayName: String
    let title: String     // For compatibility with existing code
    
    init(url: URL) {
        self.url = url
        self.accessedDate = Date()
        self.lastOpened = Date()
        self.displayName = url.lastPathComponent
        self.title = url.deletingPathExtension().lastPathComponent
    }
    
    // Custom coding to exclude auto-generated UUID from encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case url, accessedDate, lastOpened, displayName, title
        // id is excluded since it's auto-generated
    }
}

// MARK: - File Manager Service
@MainActor
class FileManagerService: ObservableObject {
    @Published var recentFiles: [RecentFile] = []
    @Published var currentFileURL: URL?
    @Published var isLoading = false
    
    private let maxRecentFiles = 10
    private let recentFilesKey = "RecentFiles"
    
    init() {
        loadRecentFiles()
    }
    
    public func clearRecentFiles() {
        recentFiles = []
        saveRecentFiles()
    }
    
    private func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: recentFilesKey)
        }
    }
    
    // MARK: - ProPresenter Master-Based Extraction
    private func extractLyricsFromMasters(_ presentation: RVData_Presentation) async throws -> String {
        print("🎵 Extracting lyrics from master cue groups...")

        var cueMap: [String: RVData_Cue] = [:]
        for cue in presentation.cues {
            cueMap[cue.uuid.string] = cue
        }

        var sections: [String] = []

        for (groupIndex, cueGroup) in presentation.cueGroups.enumerated() {
            guard cueGroup.hasGroup else {
                print("  ⚠️ Cue group \(groupIndex + 1) has no group metadata")
                continue
            }

            let sectionName = cueGroup.group.name.isEmpty ? "Section \(groupIndex + 1)" : cueGroup.group.name
            let sectionID = cueGroup.group.uuid.string
            print("Processing master section \(groupIndex + 1): '\(sectionName)' (\(sectionID.prefix(8))...) with \(cueGroup.cueIdentifiers.count) cues")

            var slideTexts: [String] = []

            for (cueIndex, cueUUID) in cueGroup.cueIdentifiers.enumerated() {
                let cueUUIDString = cueUUID.string

                guard let cue = cueMap[cueUUIDString] else {
                    print("    ⚠️ No cue found for cue UUID \(cueUUIDString.prefix(8))...")
                    continue
                }

                guard let slideText = extractDisplayTextFromCue(cue, cueIndex: cueIndex) else {
                    print("      ⚠️ No text found")
                    continue
                }

                slideTexts.append("Slide \(cueIndex + 1)\n\(slideText)")
                print("      📝 Extracted: \(slideText.prefix(30))...")
            }

            sections.append("--- \(sectionName) ---\n\n" + slideTexts.joined(separator: "\n\n"))
        }

        print("\n📈 Summary: Extracted \(sections.count) master sections")

        if sections.isEmpty {
            throw FileManagerError.invalidProPresenterFormat("No text content found in any slides")
        }

        return sections.joined(separator: "\n\n")
    }
    
    private func extractLyricsFromCues(_ presentation: RVData_Presentation) async throws -> String {
        print("🎵 Falling back to cue order extraction...")
        
        var allLyrics: [String] = []
        
        for (index, cue) in presentation.cues.enumerated() {
            if let slideText = extractTextFromCue(cue, cueIndex: index) {
                allLyrics.append(slideText)
            } else {
                allLyrics.append("") // Placeholder for empty slides
            }
        }
        
        let processedLyrics = allLyrics.joined(separator: "\n\n--- Next Slide ---\n\n")
        
        return processedLyrics
    }
    
    private func extractDisplayTextFromCue(_ cue: RVData_Cue, cueIndex: Int) -> String? {
        guard !cue.actions.isEmpty else {
            print("      ⚠️ No actions in cue")
            return nil
        }
        
        let action = cue.actions[0]
        
        guard case .slide(let slideType) = action.actionTypeData,
              case .presentation(let presentationSlide) = slideType.slide else {
            print("      ⚠️ Action is not a presentation slide type")
            return nil
        }

        let slide = presentationSlide.baseSlide
        
        guard !slide.elements.isEmpty else {
            print("      ⚠️ No elements in slide")
            return nil
        }
        
        var elementTexts: [String] = []

        for slideElement in slide.elements {
            let element = slideElement.element
            if element.hasText {
                let text = element.text
                let rtfData = text.rtfData

                let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil)
                let plainText = attributedString?.string ?? ""
                let chordAttributes = text.attributes.customAttributes.filter { !$0.chord.isEmpty }
                let displayText = applyChordAttributes(chordAttributes, to: plainText)

                elementTexts.append(displayText)
            }
        }

        return elementTexts.isEmpty ? nil : elementTexts.joined(separator: "\n")
    }

    private func extractTextFromCue(_ cue: RVData_Cue, cueIndex: Int) -> String? {
        return extractDisplayTextFromCue(cue, cueIndex: cueIndex)
    }

    private func applyChordAttributes(_ attributes: [RVData_Graphics.Text.Attributes.CustomAttribute], to plainText: String) -> String {
        guard !attributes.isEmpty else {
            return plainText
        }

        if isInstrumentalAnchorText(plainText) {
            return attributes.map { "[\($0.chord)]" }.joined(separator: "\n")
        }

        var result = plainText
        let indexedAttributes = attributes.enumerated().sorted { lhs, rhs in
            let lhsStart = lhs.element.range.start
            let rhsStart = rhs.element.range.start

            if lhsStart == rhsStart {
                return lhs.offset > rhs.offset
            }

            return lhsStart > rhsStart
        }

        for (_, attribute) in indexedAttributes {
            let safePosition = max(0, min(Int(attribute.range.start), result.count))
            let insertIndex = result.index(result.startIndex, offsetBy: safePosition)
            result.insert(contentsOf: "[\(attribute.chord)]", at: insertIndex)
        }

        return result
    }

    private func isInstrumentalAnchorText(_ plainText: String) -> Bool {
        plainText.isEmpty || plainText == "."
    }
    
    // MARK: - Smart Label Application
    func applySmartLabeling(to lyrics: String) -> String {
        let result = SongSectionAnalyzer.analyzeLyrics(lyrics)
        return result.processedText
    }
    
    // MARK: - Save File Method
    func saveFile(lyrics: String, chordMap: [String: String]) async throws {
        guard let originalURL = currentFileURL else {
            throw FileManagerError.noOriginalFile
        }
        
        let saveURL = originalURL.deletingLastPathComponent().appendingPathComponent("Updated_\(originalURL.lastPathComponent)")
        
        let parser = ProFileParser()
        try parser.addChords(to: originalURL, lyrics: lyrics, outputURL: saveURL)
    }
    
    // MARK: - Load File Method
    func loadFile(url: URL) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        let data = try Data(contentsOf: url)

        if url.pathExtension.lowercased() == "pro" {
            let presentation = try RVData_Presentation(serializedBytes: data)
            return try await extractLyricsFromMasters(presentation)
        }

        guard let lyrics = String(data: data, encoding: .utf8) else {
            throw FileManagerError.invalidProPresenterFormat("Could not read text file")
        }

        return applySmartLabeling(to: lyrics)
    }
    
    // MARK: - Recent Files Management
    private func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: recentFilesKey),
           let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
            recentFiles = files.sorted(by: { $0.accessedDate > $1.accessedDate }).prefix(maxRecentFiles).map { $0 }
        }
    }
    
    func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0.url == url }
        recentFiles.insert(RecentFile(url: url), at: 0)
        if recentFiles.count > maxRecentFiles {
            recentFiles.removeLast()
        }
        saveRecentFiles()
    }
    
    // MARK: - File Info
    func getFileInfo(for url: URL) async throws -> ProPresenterFileInfo {
        let parser = ProFileParser()
        return try await parser.analyzeProPresenterFile(url)
    }
}

// MARK: - File Manager Errors
enum FileManagerError: Error, LocalizedError {
    case fileNotFound
    case loadFailed(String)
    case saveFailed(String)
    case invalidProPresenterFormat(String)
    case noOriginalFile
    case unsupportedFileType
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .loadFailed(let message):
            return "Failed to load file: \(message)"
        case .saveFailed(let message):
            return "Failed to save file: \(message)"
        case .invalidProPresenterFormat(let message):
            return "Invalid ProPresenter file: \(message)"
        case .noOriginalFile:
            return "No original file to reference for ProPresenter export"
        case .unsupportedFileType:
            return "Unsupported file type"
        }
    }
}
