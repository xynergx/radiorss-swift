//
//  EpisodesView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData

struct EpisodesView: View {
    @Bindable var podcast: PodcastModel
    @State private var search = ""
    @EnvironmentObject private var player: PlayerViewModel

    private var bottomPadding: CGFloat {
        player.currentEpisode != nil || player.currentStation != nil ? 56 : 0
    }

    var body: some View {
        List {
            ForEach(filtered.sorted { $0.pubDate > $1.pubDate }) { e in
                EpisodeRowView(episode: e)
            }
        }
        .searchable(text: $search)
        .navigationTitle(podcast.title)
        .padding(.bottom, bottomPadding)
    }

    private var filtered: [EpisodeModel] {
        let list = podcast.episodes
        return search.isEmpty ? list : list.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
}
