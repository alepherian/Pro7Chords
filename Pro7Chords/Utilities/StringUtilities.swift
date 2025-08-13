import Foundation

// MARK: - String Utilities
struct StringUtilities {
    
    // MARK: - Chord Extraction
    static func extractChords(from text: String) -> [String] {
        let chordPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else {
            AppLogger.warning("Failed to create regex for chord extraction")
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        var chords: [String] = []
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chord = String(text[chordRange])
            chords.append(chord)
        }
        
        AppLogger.chordProcessing("Extracted \(chords.count) chords from text")
        return chords
    }
    
    // MARK: - Regex-based String Replacement
    static func replacingOccurrences(in text: String, pattern: String, with replacement: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            AppLogger.warning("Failed to create regex with pattern: \(pattern)")
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        var offset = 0
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let range = Range(NSRange(location: match.range.location + offset, length: match.range.length), in: result) else { return }
            
            let matchedText = String(result[range])
            let replacementText = replacement(matchedText)
            result.replaceSubrange(range, with: replacementText)
            offset += replacementText.count - matchedText.count
        }
        
        return result
    }
    
    // MARK: - Range Finding
    static func ranges(of pattern: String, in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { Range($0.range, in: text) }
    }
    
    static func ranges(of regex: NSRegularExpression, in text: String) -> [Range<String.Index>] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { Range($0.range, in: text) }
    }
    
    // MARK: - Validation
    static func isValidChordFormat(_ chord: String) -> Bool {
        let chordPattern = #"^([A-G][#b]?)(m|maj|dim|aug|sus[24]?|add[0-9]|[0-9]+)*(\/[A-G][#b]?)?$"#
        return chord.range(of: chordPattern, options: .regularExpression) != nil
    }
    
    static func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }
    
    static func isValidURL(_ urlString: String) -> Bool {
        return URL(string: urlString) != nil
    }
    
    // MARK: - Text Processing
    static func extractTextPreview(_ text: String, maxLength: Int = 50) -> String {
        let firstLine = text.split(separator: "\n").first ?? ""
        return String(firstLine.prefix(maxLength))
    }
    
    static func normalizeWhitespace(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
    
    static func removeExtraNewlines(_ text: String) -> String {
        return text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }
    
    static func capitalizeWords(_ text: String) -> String {
        return text.capitalized
    }
    
    static func titleCase(_ text: String) -> String {
        let articles = ["a", "an", "the"]
        let prepositions = ["at", "by", "for", "in", "of", "on", "to", "up", "and", "as", "but", "or", "nor"]
        let lowercaseWords = Set(articles + prepositions)
        
        let words = text.lowercased().components(separatedBy: .whitespaces)
        let titleCased = words.enumerated().map { index, word in
            if index == 0 || !lowercaseWords.contains(word) {
                return word.capitalized
            }
            return word
        }
        
        return titleCased.joined(separator: " ")
    }
    
    // MARK: - File Name Utilities
    static func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
        return sanitized.trimmingCharacters(in: .whitespaces)
    }
    
    static func generateUniqueFileName(baseName: String, extension: String, in directory: URL) -> String {
        let baseURL = directory.appendingPathComponent("\(baseName).\(`extension`)")
        
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            return "\(baseName).\(`extension`)"
        }
        
        var counter = 1
        while true {
            let numberedName = "\(baseName) \(counter).\(`extension`)"
            let numberedURL = directory.appendingPathComponent(numberedName)
            
            if !FileManager.default.fileExists(atPath: numberedURL.path) {
                return numberedName
            }
            
            counter += 1
        }
    }
    
    // MARK: - ChordPro Utilities
    static func insertChordAtPosition(_ text: String, chord: String, position: Int) -> String {
        let safePosition = max(0, min(position, text.count))
        let beforePosition = text.prefix(safePosition)
        let afterPosition = text.suffix(text.count - safePosition)
        
        return String(beforePosition) + "[\(chord)]" + String(afterPosition)
    }
    
    static func removeAllChords(from text: String) -> String {
        let chordPattern = #"\[[^\]]+\]"#
        return text.replacingOccurrences(of: chordPattern, with: "", options: .regularExpression)
    }
    
    static func extractLyricsOnly(from chordProText: String) -> String {
        return removeAllChords(from: chordProText)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func countLines(_ text: String) -> Int {
        return text.components(separatedBy: .newlines).count
    }
    
    static func countWords(_ text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    static func countCharacters(_ text: String, includingSpaces: Bool = true) -> Int {
        return includingSpaces ? text.count : text.replacingOccurrences(of: " ", with: "").count
    }
    
    // MARK: - Search and Highlight
    static func highlightSearchTerm(_ text: String, searchTerm: String, highlightColor: String = "yellow") -> String {
        guard !searchTerm.isEmpty else { return text }
        
        let pattern = NSRegularExpression.escapedPattern(for: searchTerm)
        return text.replacingOccurrences(
            of: pattern,
            with: "<mark style=\"background-color: \(highlightColor);\">$0</mark>",
            options: [.regularExpression, .caseInsensitive]
        )
    }
    
    // MARK: - Formatting
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Encoding/Decoding
    static func base64Encode(_ string: String) -> String? {
        return string.data(using: .utf8)?.base64EncodedString()
    }
    
    static func base64Decode(_ base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func urlEncode(_ string: String) -> String? {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    static func urlDecode(_ string: String) -> String? {
        return string.removingPercentEncoding
    }
}

// MARK: - String Extensions
extension String {
    
    // MARK: - Chord-specific extensions
    func ranges(of pattern: String) -> [Range<String.Index>] {
        return StringUtilities.ranges(of: pattern, in: self)
    }
    
    func ranges(of regex: NSRegularExpression) -> [Range<String.Index>] {
        return StringUtilities.ranges(of: regex, in: self)
    }
    
    func replacingOccurrencesUsingRegex(of pattern: String, with replacement: (String) -> String) -> String {
        return StringUtilities.replacingOccurrences(in: self, pattern: pattern, with: replacement)
    }
    
    func extractChords() -> [String] {
        return StringUtilities.extractChords(from: self)
    }
    
    func insertChord(_ chord: String, at position: Int) -> String {
        return StringUtilities.insertChordAtPosition(self, chord: chord, position: position)
    }
    
    func removeAllChords() -> String {
        return StringUtilities.removeAllChords(from: self)
    }
    
    func extractLyricsOnly() -> String {
        return StringUtilities.extractLyricsOnly(from: self)
    }
    
    // MARK: - Validation extensions
    var isValidChord: Bool {
        return StringUtilities.isValidChordFormat(self)
    }
    
    var isValidEmail: Bool {
        return StringUtilities.isValidEmail(self)
    }
    
    var isValidURL: Bool {
        return StringUtilities.isValidURL(self)
    }
    
    // MARK: - Text processing extensions
    var textPreview: String {
        return StringUtilities.extractTextPreview(self)
    }
    
    func textPreview(maxLength: Int) -> String {
        return StringUtilities.extractTextPreview(self, maxLength: maxLength)
    }
    
    var normalizedWhitespace: String {
        return StringUtilities.normalizeWhitespace(self)
    }
    
    var withoutExtraNewlines: String {
        return StringUtilities.removeExtraNewlines(self)
    }
    
    var titleCased: String {
        return StringUtilities.titleCase(self)
    }
    
    var sanitizedFileName: String {
        return StringUtilities.sanitizeFileName(self)
    }
    
    // MARK: - Counting extensions
    var lineCount: Int {
        return StringUtilities.countLines(self)
    }
    
    var wordCount: Int {
        return StringUtilities.countWords(self)
    }
    
    var characterCount: Int {
        return StringUtilities.countCharacters(self)
    }
    
    func characterCount(includingSpaces: Bool) -> Int {
        return StringUtilities.countCharacters(self, includingSpaces: includingSpaces)
    }
    
    // MARK: - Encoding extensions
    var base64Encoded: String? {
        return StringUtilities.base64Encode(self)
    }
    
    var base64Decoded: String? {
        return StringUtilities.base64Decode(self)
    }
    
    var urlEncoded: String? {
        return StringUtilities.urlEncode(self)
    }
    
    var urlDecoded: String? {
        return StringUtilities.urlDecode(self)
    }
}
