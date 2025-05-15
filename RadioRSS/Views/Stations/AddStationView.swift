//
//  AddStationView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import PhotosUI
import NukeUI

struct AddStationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var urlText = ""
    @State private var picker: PhotosPickerItem?
    @State private var data: Data?
    @State private var imageURLText = ""
    @State private var source = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Stream URL", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                Picker("", selection: $source) {
                    Text("From Phone").tag(0)
                    Text("From URL").tag(1)
                }
                .pickerStyle(.segmented)
                if source == 0 {
                    PhotosPicker(selection: $picker, matching: .images) {
                        Label("Image", systemImage: "photo")
                    }
                    .onChange(of: picker) { load() }
                    if let d = data, let i = UIImage(data: d) {
                        Image(uiImage: i)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    }
                } else {
                    TextField("Image URL", text: $imageURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    if let u = URL(string: imageURLText) {
                        LazyImage(url: u) { s in
                            if let img = s.image { img.resizable().scaledToFit() } else { Color.gray }
                        }
                        .frame(height: 150)
                    }
                }
            }
            .navigationTitle("New Station")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { add() }
                        .disabled(disabled)
                }
            }
        }
    }

    private var disabled: Bool {
        if title.isEmpty || urlText.isEmpty { return true }
        return source == 0 ? data == nil : URL(string: imageURLText) == nil
    }

    private func load() {
        Task {
            if let d = try? await picker?.loadTransferable(type: Data.self) {
                data = d
            }
        }
    }

    private func add() {
        guard let stream = URL(string: urlText) else { return }
        let artURL = source == 1 ? URL(string: imageURLText) : nil
        let imgData = source == 0 ? data : nil
        context.insert(StationModel(title: title, streamURL: stream, artworkURL: artURL, imageData: imgData))
        try? context.save()
        dismiss()
    }
}
