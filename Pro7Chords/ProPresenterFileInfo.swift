// Create a new file: ProPresenterFileInfo.swift
// Add this to your Pro7Chords project

import Foundation

struct ProPresenterFileInfo {
    let filename: String
    let slideCount: Int
    let hasExistingChords: Bool
    let textSlides: [TextSlideInfo]
}

struct TextSlideInfo: Identifiable {
    let id: String
    let previewText: String
    let hasChords: Bool
}
