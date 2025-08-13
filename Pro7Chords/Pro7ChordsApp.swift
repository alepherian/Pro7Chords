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
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .importExport) {
            Divider()
            
            Button("Recent Files...") {
                // Show recent files
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
            }
            .keyboardShortcut("k", modifiers: .command)
            
            Button("Remove All Chords") {
                // Handle chord removal
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
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            
            Button("Transpose Down") {
                // Handle transpose down
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            
            Divider()
            
            Button("Detect Key") {
                // Handle key detection
            }
            .keyboardShortcut("d", modifiers: [.command, .option])
            
            Button("Analyze Progression") {
                // Handle progression analysis
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
        }
    }
}
