//
//  Persistence.swift
//  Pro7Chords
//
//  Created by Adam Hill on 8/4/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample chord charts for preview
        let sampleChart1 = ChordChart(context: viewContext)
        sampleChart1.title = "Amazing Grace"
        sampleChart1.key = "C"
        sampleChart1.lyrics = "[C]Amazing grace how [F]sweet the sound\n[C]That saved a [G]wretch like [C]me"
        sampleChart1.createdDate = Date()
        sampleChart1.modifiedDate = Date()
        
        let sampleChart2 = ChordChart(context: viewContext)
        sampleChart2.title = "How Great Thou Art"
        sampleChart2.key = "G"
        sampleChart2.lyrics = "[G]O Lord my [C]God when [G]I in awesome wonder"
        sampleChart2.createdDate = Date().addingTimeInterval(-86400) // Yesterday
        sampleChart2.modifiedDate = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Pro7Chords")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure the container
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Convenience Methods
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func delete(_ object: NSManagedObject) {
        container.viewContext.delete(object)
        save()
    }
    
    // MARK: - Basic Chord Chart Management
    func createChordChart(title: String, key: String, lyrics: String) -> ChordChart {
        let context = container.viewContext
        let chart = ChordChart(context: context)
        chart.title = title
        chart.key = key
        chart.lyrics = lyrics
        chart.createdDate = Date()
        chart.modifiedDate = Date()
        save()
        return chart
    }
    
    func fetchChordCharts() -> [ChordChart] {
        let request: NSFetchRequest<ChordChart> = ChordChart.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChordChart.modifiedDate, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
}
