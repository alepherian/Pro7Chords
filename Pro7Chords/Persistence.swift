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
        let sampleChart1 = ChordChart.create(
            in: viewContext,
            title: "Amazing Grace",
            key: "C",
            lyrics: "[C]Amazing grace how [F]sweet the sound\n[C]That saved a [G]wretch like [C]me"
        )
        sampleChart1.generateChordPositions()
        
        let sampleChart2 = ChordChart.create(
            in: viewContext,
            title: "How Great Thou Art",
            key: "G",
            lyrics: "[G]O Lord my [C]God when [G]I in awesome wonder\n[Am]Consider [G]all the [D]worlds thy hands have [G]made"
        )
        sampleChart2.createdDate = Date().addingTimeInterval(-86400) // Yesterday
        sampleChart2.generateChordPositions()
        
        let sampleChart3 = ChordChart.create(
            in: viewContext,
            title: "10,000 Reasons",
            key: "F",
            lyrics: "[F]Bless the Lord O [Am]my soul\n[Bb]O my soul\n[F]Worship His holy [C]name"
        )
        sampleChart3.createdDate = Date().addingTimeInterval(-172800) // 2 days ago
        sampleChart3.generateChordPositions()
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. 
            // You should not use this function in a shipping application, although it may be useful during development.
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
                // In a shipping application, you would handle this error appropriately
                // For development, we'll print the error and continue
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
    
    // MARK: - Chord Chart Management
    func createChordChart(title: String, key: String, lyrics: String) -> ChordChart {
        let context = container.viewContext
        let chart = ChordChart.create(in: context, title: title, key: key, lyrics: lyrics)
        chart.generateChordPositions()
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
    
    func searchChordCharts(query: String) -> [ChordChart] {
        let request: NSFetchRequest<ChordChart> = ChordChart.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR lyrics CONTAINS[cd] %@", query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChordChart.modifiedDate, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    func fetchChordChartsByKey(_ key: String) -> [ChordChart] {
        let request: NSFetchRequest<ChordChart> = ChordChart.fetchRequest()
        request.predicate = NSPredicate(format: "key == %@", key)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChordChart.modifiedDate, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Fetch by key error: \(error)")
            return []
        }
    }
    
    func updateChordChart(_ chart: ChordChart, title: String? = nil, key: String? = nil, lyrics: String? = nil) {
        if let title = title {
            chart.title = title
        }
        if let key = key {
            chart.key = key
        }
        if let lyrics = lyrics {
            chart.lyrics = lyrics
            chart.generateChordPositions() // Regenerate chord positions when lyrics change
        }
        chart.touch()
        save()
    }
    
    // MARK: - Chord Position Management
    func fetchChordPositions(for chart: ChordChart) -> [ChordPositionEntity] {
        return chart.chordPositionsArray
    }
    
    func addChordPosition(to chart: ChordChart, chord: String, slideId: String, position: Int) {
        chart.addChordPosition(chord: chord, slideId: slideId, position: Int32(position))
        save()
    }
    
    // MARK: - Statistics
    func getTotalChordChartsCount() -> Int {
        let request: NSFetchRequest<ChordChart> = ChordChart.fetchRequest()
        
        do {
            return try container.viewContext.count(for: request)
        } catch {
            print("Count error: \(error)")
            return 0
        }
    }
    
    func getRecentlyModifiedCharts(limit: Int = 5) -> [ChordChart] {
        let request: NSFetchRequest<ChordChart> = ChordChart.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChordChart.modifiedDate, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Recent charts fetch error: \(error)")
            return []
        }
    }
    
    func getMostUsedKeys() -> [String: Int] {
        let charts = fetchChordCharts()
        var keyCounts: [String: Int] = [:]
        
        for chart in charts {
            let key = chart.displayKey
            keyCounts[key, default: 0] += 1
        }
        
        return keyCounts
    }
}

// MARK: - Error Handling
extension PersistenceController {
    
    enum PersistenceError: Error, LocalizedError {
        case invalidChordChart
        case saveError(Error)
        case fetchError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidChordChart:
                return "Invalid chord chart data"
            case .saveError(let error):
                return "Failed to save: \(error.localizedDescription)"
            case .fetchError(let error):
                return "Failed to fetch: \(error.localizedDescription)"
            }
        }
    }
}
