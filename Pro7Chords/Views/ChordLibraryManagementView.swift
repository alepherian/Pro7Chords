import SwiftUI
import CoreData

// MARK: - Chord Library View with Core Data Integration
struct ChordLibraryManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
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
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chart") {
                        showingNewChartSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingNewChartSheet) {
                NewChordChartView()
            }
            .sheet(item: $selectedChart) { chart in
                ChordChartDetailView(chart: chart)
            }
        }
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
        List {
            ForEach(filteredCharts, id: \.objectID) { chart in
                ChordChartRow(chart: chart) {
                    selectedChart = chart
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        deleteChart(chart)
                    }
                    
                    Button("Duplicate") {
                        duplicateChart(chart)
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
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
            } catch {
                print("Delete error: \(error)")
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
        } catch {
            print("Duplicate error: \(error)")
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
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(chart.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Lyrics Preview
                    Text(chart.safeContent.prefix(80))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Metadata
                    HStack {
                        if chart.chordCount > 0 {
                            Text("\(chart.chordCount) chords")
                                .font(.caption2)
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
                
                Spacer()
                
                // Chord Count Badge
                if chart.chordCount > 0 {
                    VStack {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(chart.chordCount)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
            Form {
                Section("Chart Information") {
                    TextField("Chart Title", text: $title)
                    
                    Picker("Key", selection: $key) {
                        ForEach(musicKeys, id: \.self) { musicKey in
                            Text(musicKey).tag(musicKey)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Lyrics & Chords") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use ChordPro format: [C]Amazing [F]grace")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $lyrics)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200)
                    }
                }
                
                Section("Templates") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
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
            .navigationTitle("New Chord Chart")
            .navigationBarTitleDisplayMode(.inline)
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
            dismiss()
        } catch {
            print("Save error: \(error)")
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
            VStack(spacing: 0) {
                if isEditing {
                    editingView
                } else {
                    detailView
                }
            }
            .navigationTitle(chart.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
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
        ScrollView {
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
    }
    
    // MARK: - Editing View
    private var editingView: some View {
        Form {
            Section("Chart Information") {
                TextField("Chart Title", text: $editTitle)
                
                Picker("Key", selection: $editKey) {
                    ForEach(musicKeys, id: \.self) { musicKey in
                        Text(musicKey).tag(musicKey)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Lyrics & Chords") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use ChordPro format: [C]Amazing [F]grace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $editLyrics)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                }
            }
        }
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
            isEditing = false
        } catch {
            print("Save error: \(error)")
        }
    }
}

#Preview {
    ChordLibraryManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
