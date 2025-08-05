//
//  Pro7ChordsApp.swift
//  Pro7Chords
//
//  Created by Adam Hill on 8/4/25.
//

import SwiftUI

@main
struct Pro7ChordsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
