//
//  ChordPositionEntity+CoreDataProperties.swift
//  Pro7Chords
//
//  Created by Core Data on 8/4/25.
//

import Foundation
import CoreData

extension ChordPositionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChordPositionEntity> {
        return NSFetchRequest<ChordPositionEntity>(entityName: "ChordPositionEntity")
    }

    @NSManaged public var chord: String?
    @NSManaged public var position: Int32
    @NSManaged public var slideId: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var chordChart: ChordChart?

}

extension ChordPositionEntity : Identifiable {

}
