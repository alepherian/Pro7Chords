import SwiftUI

// MARK: - Chord Library View
struct ChordLibraryView: View {
    @Binding var selectedChord: String
    let onChordSelected: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory = "Common"
    
    private let chordCategories = [
        "Common": ["C", "G", "Am", "F", "D", "Em", "A"],
        "Major": ["C", "D", "E", "F", "G", "A", "B", "Db", "Eb", "Gb", "Ab", "Bb"],
        "Minor": ["Cm", "Dm", "Em", "Fm", "Gm", "Am", "Bm", "C#m", "D#m", "F#m", "G#m", "A#m"],
        "7th": ["C7", "D7", "E7", "F7", "G7", "A7", "B7", "Cmaj7", "Dmaj7", "Emaj7", "Fmaj7"],
        "Extended": ["C9", "D11", "F13", "Am9", "Dm11", "G13", "Cadd9", "Fadd9", "Gsus2", "Dsus4"],
        "Jazz": ["Cmaj9", "Dm9", "G13", "Am11", "F#m7b5", "Bb7#11", "Cm(maj7)", "D7alt"]
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Chord Library")
                .font(.headline)
                .padding()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search chords...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !searchText.isEmpty {
                            selectedChord = searchText
                            onChordSelected(searchText)
                        }
                    }
            }
            .padding(.horizontal)
            
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(chordCategories.keys.sorted(), id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Chord grid
            ScrollView {
                let filteredChords = getFilteredChords()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 8) {
                    ForEach(filteredChords, id: \.self) { chord in
                        ChordButton(
                            chord: chord,
                            isSelected: selectedChord == chord,
                            action: {
                                selectedChord = chord
                                onChordSelected(chord)
                            }
                        )
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private func getFilteredChords() -> [String] {
        let categoryChords = chordCategories[selectedCategory] ?? []
        
        if searchText.isEmpty {
            return categoryChords
        } else {
            return categoryChords.filter { chord in
                chord.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Chord Button
struct ChordButton: View {
    let chord: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(chord)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(backgroundColor)
                .cornerRadius(6)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color(.controlColor)
        }
    }
    
    private var textColor: Color {
        isSelected ? .white : .primary
    }
}

// MARK: - Chord Preview View
struct ChordPreviewView: View {
    let chord: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chord Preview")
                .font(.headline)
            
            if let chordObj = Chord(from: chord) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Root:")
                            .fontWeight(.medium)
                        Text(chordObj.root)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Quality:")
                            .fontWeight(.medium)
                        Text(chordObj.quality.displayName)
                    }
                    
                    if !chordObj.extensions.isEmpty {
                        HStack {
                            Text("Extensions:")
                                .fontWeight(.medium)
                            Text(chordObj.extensions.joined(separator: ", "))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    
                    if let bassNote = chordObj.bassNote {
                        HStack {
                            Text("Bass Note:")
                                .fontWeight(.medium)
                            Text(bassNote)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                Text("Invalid chord format")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - File Info View
struct FileInfoView: View {
    let fileInfo: ProPresenterFileInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("File Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            
            // File details
            Grid(alignment: .leading, horizontalSpacing: 16) {
                GridRow {
                    Text("Filename:")
                        .fontWeight(.medium)
                    Text(fileInfo.filename)
                        .font(.system(.body, design: .monospaced))
                }
                
                GridRow {
                    Text("Total Slides:")
                        .fontWeight(.medium)
                    Text("\(fileInfo.slideCount)")
                }
                
                GridRow {
                    Text("Has Existing Chords:")
                        .fontWeight(.medium)
                    HStack {
                        Image(systemName: fileInfo.hasExistingChords ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(fileInfo.hasExistingChords ? .green : .orange)
                        Text(fileInfo.hasExistingChords ? "Yes" : "No")
                    }
                }
                
                GridRow {
                    Text("Text Slides:")
                        .fontWeight(.medium)
                    Text("\(fileInfo.textSlides.count)")
                }
            }
            
            Divider()
            
            // Slide list
            if !fileInfo.textSlides.isEmpty {
                Text("Slide Contents")
                    .font(.headline)
                
                List(fileInfo.textSlides) { slide in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(slide.previewText)
                                .font(.body)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if slide.hasChords {
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        
                        Text("ID: \(slide.id.prefix(8))...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 200)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
    }
}

#Preview {
    ChordLibraryView(selectedChord: .constant("C")) { _ in }
        .frame(width: 250, height: 500)
}
