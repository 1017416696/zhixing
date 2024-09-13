//
//  NoteStore.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/13.
//

import SwiftUI

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []
    
    init() {
        loadNotes()
    }
    
    func addNote(_ note: Note) {
        notes.append(note)
        saveNotes()
    }
    
    func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            notes[index] = updatedNote
            saveNotes()
        }
    }
    
    private func saveNotes() {
        if let encodedData = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encodedData, forKey: "notes")
        }
    }
    
    private func loadNotes() {
        if let savedNotes = UserDefaults.standard.data(forKey: "notes"),
           let decodedNotes = try? JSONDecoder().decode([Note].self, from: savedNotes) {
            notes = decodedNotes
        }
    }
}
