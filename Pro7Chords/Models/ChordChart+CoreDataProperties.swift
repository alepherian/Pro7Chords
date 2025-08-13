//
//  ChordChart+CoreDataProperties.swift
//  Pro7Chords
//
//  Created by Core Data on 8/4/25.
//

import Foundation
import CoreData

extension ChordChart {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChordChart> {
        return NSFetchRequest<ChordChart>(entityName: "ChordChart")
    }

    @NSManaged public var createdDate: Date?
    @NSManaged public var key: String?
    @NSManaged public var lyrics: String?
    @NSManaged public var modifiedDate: Date?
    @NSManaged public var originalFileURL: URL?
    @NSManaged public var title: String?
    @NSManaged public var chordPositions: NSSet?

}

// MARK: Generated accessors for chordPositions
extension ChordChart {

    @objc(addChordPositionsObject:)
    @NSManaged public func addToChordPositions(_ value: ChordPositionEntity)

    @objc(removeChordPositionsObject:)
    @NSManaged public func removeFromChordPositions(_ value: ChordPositionEntity)

    @objc(addChordPositions:)
    @NSManaged public func addToChordPositions(_ values: NSSet)

    @objc(removeChordPositions:)
    @NSManaged public func removeFromChordPositions(_ values: NSSet)

}

extension ChordChart : Identifiable {

}
