import SwiftUI

@main
struct Pro7ChordsApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ChordEditorView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            FileMenuCommands()
            EditMenuCommands()
            ChordMenuCommands()
        }
    }
}

// MARK: - Custom Menu Commands
struct FileMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Chord Chart") {
                // Handle new file creation
                NotificationCenter.default.post(name: .newChordChart, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .newItem) {
            Button("Open...") {
                // Handle file opening
                NotificationCenter.default.post(name: .openFile, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        
        CommandGroup(after: .importExport) {
            Divider()
            
            Button("Recent Files...") {
                // Show recent files
                NotificationCenter.default.post(name: .showRecentFiles, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

struct EditMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .undoRedo) {
            Divider()
            
            Button("Insert Chord") {
                // Handle chord insertion
                NotificationCenter.default.post(name: .insertChord, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Button("Remove All Chords") {
                // Handle chord removal
                NotificationCenter.default.post(name: .removeAllChords, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
    }
}

struct ChordMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Chords") {
            Button("Transpose Up") {
                // Handle transpose up
                NotificationCenter.default.post(name: .transposeUp, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            
            Button("Transpose Down") {
                // Handle transpose down
                NotificationCenter.default.post(name: .transposeDown, object: nil)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            
            Divider()
            
            Button("Detect Key") {
                // Handle key detection
                NotificationCenter.default.post(name: .detectKey, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            
            Button("Analyze Progression") {
                // Handle progression analysis
                NotificationCenter.default.post(name: .analyzeProgression, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            
            Button("Smart Labels") {
                // Apply smart section labeling
                NotificationCenter.default.post(name: .applySmartLabels, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            
            Divider()
            
            Button("Chord Library...") {
                // Show chord library
                NotificationCenter.default.post(name: .showChordLibrary, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let newChordChart = Notification.Name("newChordChart")
    static let openFile = Notification.Name("openFile")
    static let showRecentFiles = Notification.Name("showRecentFiles")
    static let insertChord = Notification.Name("insertChord")
    static let removeAllChords = Notification.Name("removeAllChords")
    static let transposeUp = Notification.Name("transposeUp")
    static let transposeDown = Notification.Name("transposeDown")
    static let detectKey = Notification.Name("detectKey")
    static let analyzeProgression = Notification.Name("analyzeProgression")
    static let applySmartLabels = Notification.Name("applySmartLabels")
    static let showChordLibrary = Notification.Name("showChordLibrary")
}
