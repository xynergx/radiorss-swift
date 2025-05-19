//
//  PodcastsView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NukeUI

struct PodcastsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\PodcastModel.title, order: .forward)]) private var podcasts: [PodcastModel]
    @State private var search = ""
    @State private var showingAdd = false
    @State private var showingImportFile = false
    @State private var showingImportURL = false
    @State private var exporting = false
    @State private var exportDoc = PodcastURLsTextFile()
    @State private var target: PodcastModel?
    @EnvironmentObject private var player: PlayerViewModel

    private var bottomPadding: CGFloat {
        player.currentEpisode != nil || player.currentStation != nil ? 56 : 0
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { podcast in
                    NavigationLink {
                        EpisodesView(podcast: podcast)
                    } label: {
                        HStack {
                            LazyImage(url: podcast.artworkURL) { s in
                                if let img = s.image { img.resizable().scaledToFill() } else { Color.gray }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(podcast.title)
                            Spacer()
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { target = podcast } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Podcasts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New Podcast") { showingAdd = true }
                        Button("Import from File") { showingImportFile = true }
                        Button("Import from URL") { showingImportURL = true }
                        Button("Export URL's") { prepareExport() }
                    } label: { Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .padding(.bottom, bottomPadding)
            .sheet(isPresented: $showingAdd) { AddPodcastView() }
            .sheet(isPresented: $showingImportFile) { ImportPodcastsFileView() }
            .sheet(isPresented: $showingImportURL) { ImportPodcastsURLView() }
            .alert("Delete this podcast?",
                   isPresented: Binding(get: { target != nil },
                                        set: { if !$0 { target = nil } })) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let podcast = target {
                        context.delete(podcast)
                        try? context.save()
                    }
                    target = nil
                }
            }
        }
        .fileExporter(isPresented: $exporting,
                      document: exportDoc,
                      contentType: .plainText,
                      defaultFilename: "podcast_urls") { _ in }
    }

    private func prepareExport() {
        let urls = podcasts.map { $0.feedURL.absoluteString }
        exportDoc.text = urls.joined(separator: "\n")
        exporting = true
    }

    private var filtered: [PodcastModel] {
        search.isEmpty ? podcasts : podcasts.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
}
