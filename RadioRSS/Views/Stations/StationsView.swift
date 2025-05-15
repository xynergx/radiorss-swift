//
//  StationsView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NukeUI

struct StationsView: View {
    @Environment(\.modelContext) private var context
    @Query private var stations: [StationModel]
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImportFile = false
    @State private var showingImportURL = false
    @State private var exporting = false
    @State private var exportDoc = StationsJSONFile()
    @State private var target: StationModel?
    @EnvironmentObject private var player: PlayerViewModel

    private var bottomPadding: CGFloat {
        player.currentEpisode != nil || player.currentStation != nil ? 56 : 0
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { r in
                    HStack {
                        image(for: r)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(r.title)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.play(station: r) }
                    .swipeActions {
                        Button(role: .destructive) { target = r } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Stations")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New Station") { showingAdd = true }
                        Button("Import from File") { showingImportFile = true }
                        Button("Import from URL") { showingImportURL = true }
                        Button("Export JSON") { prepareExport() }
                    } label: { Image(systemName: "plus") }
                }
            }
            .padding(.bottom, bottomPadding)
            .sheet(isPresented: $showingAdd) { AddStationView() }
            .sheet(isPresented: $showingImportFile) { ImportStationsFileView() }
            .sheet(isPresented: $showingImportURL) { ImportStationsURLView() }
            .alert("Delete this station?",
                   isPresented: Binding(get: { target != nil },
                                        set: { if !$0 { target = nil } })) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let r = target {
                        context.delete(r)
                        try? context.save()
                    }
                    target = nil
                }
            }
        }
        .fileExporter(isPresented: $exporting,
                      document: exportDoc,
                      contentType: .json,
                      defaultFilename: "stations") { _ in }
    }

    private func prepareExport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let records = stations.map {
            StationExportModel(title: $0.title,
                          streamURL: $0.streamURL.absoluteString,
                          artworkURL: $0.artworkURL?.absoluteString)
        }
        if let data = try? encoder.encode(records) {
            exportDoc = StationsJSONFile(data: data)
            exporting = true
        }
    }

    private var filtered: [StationModel] {
        search.isEmpty ? stations : stations.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    @ViewBuilder private func image(for r: StationModel) -> some View {
        if let d = r.imageData, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let u = r.artworkURL {
            LazyImage(url: u) { s in
                if let img = s.image { img.resizable().scaledToFill() } else { Color.gray }
            }
        } else {
            Color.gray
        }
    }
}
