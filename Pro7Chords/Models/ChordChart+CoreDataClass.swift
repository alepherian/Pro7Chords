//
//  ChordChart+CoreDataClass.swift
//  Pro7Chords
//
//  Created by Core Data on 8/4/25.
//

import Foundation
import CoreData

@objc(ChordChart)
public class ChordChart: NSManagedObject {
    
    // MARK: - Computed Properties
    
    /// Display name for the chart
    public var displayTitle: String {
        return title ?? "Untitled Chart"
    }
    
    /// Display key for the chart
    public var displayKey: String {
        return key ?? "C"
    }
    
    /// Safe lyrics content
    public var safeContent: String {
        return lyrics ?? ""
    }
    
    /// Array of chord positions
    public var chordPositionsArray: [ChordPositionEntity] {
        let set = chordPositions as? Set<ChordPositionEntity> ?? []
        return set.sorted { $0.position < $1.position }
    }
    
    // MARK: - Convenience Methods
    
    /// Creates a new chord chart
    static func create(in context: NSManagedObjectContext,
                      title: String,
                      key: String = "C",
                      lyrics: String = "") -> ChordChart {
        let chart = ChordChart(context: context)
        chart.title = title
        chart.key = key
        chart.lyrics = lyrics
        chart.createdDate = Date()
        chart.modifiedDate = Date()
        return chart
    }
    
    /// Updates the modified date
    func touch() {
        modifiedDate = Date()
    }
    
    /// Adds a chord position to this chart
    func addChordPosition(chord: String, slideId: String, position: Int32) {
        let chordPosition = ChordPositionEntity(context: managedObjectContext!)
        chordPosition.chord = chord
        chordPosition.slideId = slideId
        chordPosition.position = position
        chordPosition.timestamp = Date()
        chordPosition.chordChart = self
        
        touch()
    }
    
    /// Removes all chord positions
    func clearChordPositions() {
        if let positions = chordPositions {
            for position in positions {
                managedObjectContext?.delete(position as! NSManagedObject)
            }
        }
        touch()
    }
    
    /// Extracts chords from lyrics and creates chord positions
    func generateChordPositions() {
        clearChordPositions()
        
        let chordPattern = #"\[([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: chordPattern) else { return }
        
        let text = safeContent
        let range = NSRange(text.startIndex..., in: text)
        
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let chordRange = Range(match.range(at: 1), in: text) else { return }
            
            let chord = String(text[chordRange])
            let position = match.range.location
            
            addChordPosition(chord: chord, slideId: "main", position: Int32(position))
        }
    }
    
    /// Gets unique chords used in this chart
    var uniqueChords: [String] {
        let chords = chordPositionsArray.map { $0.chord ?? "" }
        return Array(Set(chords)).filter { !$0.isEmpty }.sorted()
    }
    
    /// Count of total chords in this chart
    var chordCount: Int {
        return chordPositionsArray.count
    }
}

// MARK: - Validation
extension ChordChart {
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateChart()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateChart()
    }
    
    private func validateChart() throws {
        // Ensure we have a title
        if title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            title = "Untitled Chart"
        }
        
        // Ensure we have a key
        if key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            key = "C"
        }
        
        // Ensure we have created and modified dates
        if createdDate == nil {
            createdDate = Date()
        }
        
        if modifiedDate == nil {
            modifiedDate = Date()
        }
    }
}
