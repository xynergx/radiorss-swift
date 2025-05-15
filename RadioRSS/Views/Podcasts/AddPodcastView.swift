//
//  AddPodcastView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData

struct AddPodcastView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var urlText = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("RSS URL", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                if busy { ProgressView() }
            }
            .navigationTitle("New Podcast")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { add() }
                        .disabled(urlText.isEmpty || busy)
                }
            }
        }
    }

    private func add() {
        guard let feedURL = URL(string: urlText) else { return }
        busy = true
        Task {
            do {
                let (title, artworkURL, eps) = try await FeedParserService().parse(url: feedURL)
                let p = PodcastModel(title: title, feedURL: feedURL, artworkURL: artworkURL)
                context.insert(p)
                for (t, au, art, date) in eps {
                    let episode = EpisodeModel(title: t, audioURL: au, artworkURL: art, pubDate: date, podcast: p)
                    p.episodes.append(episode)
                }
                try context.save()
                dismiss()
            } catch {
                busy = false
            }
        }
    }
}
