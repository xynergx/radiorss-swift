//
//  EpisodeRowView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import NukeUI

struct EpisodeRowView: View {
    @Bindable var episode: EpisodeModel
    @EnvironmentObject private var player: PlayerViewModel
    
    var body: some View {
        HStack {
            LazyImage(url: episode.artworkURL ?? episode.podcast?.artworkURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.gray
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                if let bar = progressBar { bar }
            }
            .onTapGesture { player.play(episode: episode) }
            Spacer()
        }
    }
    
    private var progressBar: AnyView? {
        guard let dur = episode.duration, dur > 0 else { return nil }
        let ratio = min(max(episode.progress / dur, 0), 1)
        return ratio == 0 ? nil : AnyView(ProgressView(value: ratio))
    }
}
