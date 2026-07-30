import SwiftUI
import CoreData

// MARK: - ChordChart Extensions
extension ChordChart {
    var displayKey: String {
        return key ?? "C"
    }
    
    var displayTitle: String {
        return title ?? "Untitled"
    }
    
    var safeContent: String {
        return lyrics ?? ""
    }
    
    var chordCount: Int {
        return StringUtilities.extractChords(from: safeContent).count
    }
    
    var uniqueChords: [String] {
        let chords = StringUtilities.extractChords(from: safeContent)
        return Array(Set(chords)).sorted()
    }
    
    // Create a new ChordChart with validation
    static func create(in context: NSManagedObjectContext, title: String, key: String, lyrics: String) -> ChordChart {
        let chart = ChordChart(context: context)
        chart.title = title
        chart.key = key
        chart.lyrics = lyrics
        chart.createdDate = Date()
        chart.modifiedDate = Date()
        return chart
    }
    
    // Update modification date
    func touch() {
        self.modifiedDate = Date()
    }
    
    // Generate chord positions (placeholder - implement based on your needs)
    func generateChordPositions() {
        // This method would analyze the lyrics and create ChordPositionEntity objects
        // For now, we'll just update the modified date
        self.touch()
    }
}

// MARK: - Chord Library View with Core Data Integration
struct ChordLibraryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChordChart.modifiedDate, ascending: false)],
        animation: .default)
    private var chordCharts: FetchedResults<ChordChart>
    
    @State private var searchText = ""
    @State private var selectedKey = "All"
    @State private var showingNewChartSheet = false
    @State private var selectedChart: ChordChart?
    
    private let musicKeys = ["All", "C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb"]
    
    var filteredCharts: [ChordChart] {
        let charts = Array(chordCharts)
        
        let keyFiltered = selectedKey == "All" ? charts : charts.filter { 
            $0.displayKey == selectedKey 
        }
        
        if searchText.isEmpty {
            return keyFiltered
        } else {
            return keyFiltered.filter { chart in
                chart.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                chart.safeContent.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Header
                headerView
                
                // Charts List
                if filteredCharts.isEmpty {
                    emptyStateView
                } else {
                    chartsList
                }
            }
            .navigationTitle("Chord Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chart") {
                        showingNewChartSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingNewChartSheet) {
                NewChordChartView()
                    .frame(minWidth: 600, minHeight: 500)
            }
            .sheet(item: $selectedChart) { chart in
                ChordChartDetailView(chart: chart)
                    .frame(minWidth: 600, minHeight: 500)
            }
        }
        .frame(minWidth: 700, minHeight: 500)  // FIXED: Proper minimum size
        .frame(idealWidth: 800, idealHeight: 600)  // FIXED: Ideal size
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search chord charts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Key Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(musicKeys, id: \.self) { key in
                        Button(key) {
                            selectedKey = key
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(selectedKey == key ? .white : .primary)
                        .background(selectedKey == key ? Color.blue : Color.clear)
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
            }
            
            // Stats
            HStack {
                Text("\(filteredCharts.count) charts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if selectedKey != "All" {
                    Text("Key: \(selectedKey)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    // MARK: - Charts List
    private var chartsList: some View {
        ScrollView {  // FIXED: Added ScrollView wrapper
            LazyVStack(spacing: 8) {  // FIXED: Using LazyVStack for better performance
                ForEach(filteredCharts, id: \.objectID) { chart in
                    ChordChartRow(chart: chart) {
                        selectedChart = chart
                    }
                    .contextMenu {
                        Button("Edit") {
                            selectedChart = chart
                        }
                        
                        Button("Duplicate") {
                            duplicateChart(chart)
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            deleteChart(chart)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.textBackgroundColor))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Chord Charts")
                .font(.headline)
            
            Text(searchText.isEmpty ? "Create your first chord chart to get started" : "No charts match your search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("Create Chart") {
                    showingNewChartSheet = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Clear Search") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    private func deleteChart(_ chart: ChordChart) {
        withAnimation {
            viewContext.delete(chart)
            
            do {
                try viewContext.save()
                AppLogger.coreData("Deleted chord chart: \(chart.displayTitle)")
            } catch {
                AppLogger.error("Failed to delete chord chart", error: error, category: .coreData)
            }
        }
    }
    
    private func duplicateChart(_ chart: ChordChart) {
        let duplicate = ChordChart.create(
            in: viewContext,
            title: "\(chart.displayTitle) Copy",
            key: chart.displayKey,
            lyrics: chart.safeContent
        )
        duplicate.generateChordPositions()
        
        do {
            try viewContext.save()
            AppLogger.coreData("Duplicated chord chart: \(chart.displayTitle)")
        } catch {
            AppLogger.error("Failed to duplicate chord chart", error: error, category: .coreData)
        }
    }
}

// MARK: - Chord Chart Row
struct ChordChartRow: View {
    let chart: ChordChart
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Key Badge
                Text(chart.displayKey)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                    .frame(minWidth: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(chart.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Lyrics Preview
                    if !chart.safeContent.isEmpty {
                        Text(chart.safeContent.prefix(100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No lyrics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // Metadata
                    HStack {
                        if chart.chordCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.caption2)
                                Text("\(chart.chordCount) chords")
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let modifiedDate = chart.modifiedDate {
                            Text(modifiedDate, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())  // FIXED: Makes entire area tappable
    }
}

// MARK: - New Chord Chart View
struct NewChordChartView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var key = "C"
    @State private var lyrics = ""
    
    private let musicKeys = ["C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb"]
    
    var body: some View {
        NavigationView {
            ScrollView {  // FIXED: Added ScrollView for better content handling
                VStack(spacing: 20) {
                    // Chart Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chart Information")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Title:")
                                    .frame(width: 60, alignment: .leading)
                                TextField("Chart Title", text: $title)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Key:")
                                    .frame(width: 60, alignment: .leading)
                                Picker("Key", selection: $key) {
                                    ForEach(musicKeys, id: \.self) { musicKey in
                                        Text(musicKey).tag(musicKey)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                                Spacer()
                            }
                        }
                    }
                    
                    // Lyrics Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lyrics & Chords")
                            .font(.headline)
                        
                        Text("Use ChordPro format: [C]Amazing [F]grace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $lyrics)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 250)
                            .padding(4)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                    }
                    
                    // Templates Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Templates")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(["Verse", "Chorus", "Bridge", "Intro", "Outro"], id: \.self) { template in
                                Button(template) {
                                    insertTemplate(template)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Chord Chart")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChart()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func insertTemplate(_ templateName: String) {
        let template = """
        
        === \(templateName) ===
        
        
        """
        lyrics += template
    }
    
    private func saveChart() {
        let chart = ChordChart.create(
            in: viewContext,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            key: key,
            lyrics: lyrics
        )
        chart.generateChordPositions()
        
        do {
            try viewContext.save()
            AppLogger.coreData("Created new chord chart: \(chart.displayTitle)")
            dismiss()
        } catch {
            AppLogger.error("Failed to save new chord chart", error: error, category: .coreData)
        }
    }
}

// MARK: - Chord Chart Detail View
struct ChordChartDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var chart: ChordChart
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editKey = ""
    @State private var editLyrics = ""
    
    private let musicKeys = ["C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb"]
    
    var body: some View {
        NavigationView {
            ScrollView {  // FIXED: Always wrapped in ScrollView
                if isEditing {
                    editingView
                } else {
                    detailView
                }
            }
            .navigationTitle(chart.displayTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
                
                if isEditing {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Cancel") {
                            cancelEditing()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Detail View
    private var detailView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Chart Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Key: \(chart.displayKey)")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("\(chart.chordCount) chords")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let modifiedDate = chart.modifiedDate {
                    Text("Modified \(modifiedDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Unique Chords
            if !chart.uniqueChords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chords Used")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(chart.uniqueChords, id: \.self) { chord in
                            Text(chord)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Lyrics
            VStack(alignment: .leading, spacing: 8) {
                Text("Lyrics & Chords")
                    .font(.headline)
                
                Text(chart.safeContent.isEmpty ? "No lyrics added yet" : chart.safeContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            }
        }
        .padding()
    }
    
    // MARK: - Editing View
    private var editingView: some View {
        VStack(spacing: 20) {
            // Chart Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Chart Information")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Title:")
                            .frame(width: 60, alignment: .leading)
                        TextField("Chart Title", text: $editTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack {
                        Text("Key:")
                            .frame(width: 60, alignment: .leading)
                        Picker("Key", selection: $editKey) {
                            ForEach(musicKeys, id: \.self) { musicKey in
                                Text(musicKey).tag(musicKey)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        Spacer()
                    }
                }
            }
            
            // Lyrics
            VStack(alignment: .leading, spacing: 8) {
                Text("Lyrics & Chords")
                    .font(.headline)
                
                Text("Use ChordPro format: [C]Amazing [F]grace")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $editLyrics)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 300)
                    .padding(4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    private func startEditing() {
        editTitle = chart.displayTitle
        editKey = chart.displayKey
        editLyrics = chart.safeContent
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
    }
    
    private func saveChanges() {
        chart.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        chart.key = editKey
        chart.lyrics = editLyrics
        chart.touch()
        chart.generateChordPositions()
        
        do {
            try viewContext.save()
            AppLogger.coreData("Updated chord chart: \(chart.displayTitle)")
            isEditing = false
        } catch {
            AppLogger.error("Failed to save chord chart changes", error: error, category: .coreData)
        }
    }
}

#Preview {
    ChordLibraryManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
