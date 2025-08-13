//
//  ChordPositionEntity+Extensions.swift
//  Pro7Chords
//
//  Created on 8/4/25.
//

import Foundation
import CoreData

// MARK: - ChordPositionEntity Extensions
extension ChordPositionEntity {
    
    // MARK: - Computed Properties
    
    /// Safe chord name
    public var safeChord: String {
        return chord ?? ""
    }
    
    /// Safe slide identifier
    public var safeSlideId: String {
        return slideId ?? ""
    }
    
    /// Safe timestamp
    public var safeTimestamp: Date {
        return timestamp ?? Date()
    }
    
    // MARK: - Convenience Methods
    
    /// Creates a new chord position
    static func create(in context: NSManagedObjectContext,
                      chord: String,
                      slideId: String,
                      position: Int32,
                      chordChart: ChordChart? = nil) -> ChordPositionEntity {
        let entity = ChordPositionEntity(context: context)
        entity.chord = chord
        entity.slideId = slideId
        entity.position = position
        entity.timestamp = Date()
        entity.chordChart = chordChart
        return entity
    }
    
    /// Updates the timestamp
    func touch() {
        timestamp = Date()
    }
}

// MARK: - Validation
extension ChordPositionEntity {
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateChordPosition()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateChordPosition()
    }
    
    private func validateChordPosition() throws {
        // Ensure we have a chord
        if chord?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            throw NSError(domain: "ChordPositionEntityValidation", 
                         code: 1001, 
                         userInfo: [NSLocalizedDescriptionKey: "Chord cannot be empty"])
        }
        
        // Ensure we have a slide ID
        if slideId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            slideId = "main"
        }
        
        // Ensure we have a timestamp
        if timestamp == nil {
            timestamp = Date()
        }
        
        // Ensure position is not negative
        if position < 0 {
            position = 0
        }
    }
}

// MARK: - Fetch Request Helper
extension ChordPositionEntity {
    
    /// Convenience method for creating fetch requests
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChordPositionEntity> {
        return NSFetchRequest<ChordPositionEntity>(entityName: "ChordPositionEntity")
    }
}
