//
//  PlayerView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import NukeUI

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerViewModel

    private func fmt(_ s: Double) -> String {
        let t = Int(s)
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }

    var body: some View {
        VStack(spacing: 24) {
            image
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(player.currentEpisode?.title ?? player.currentStation?.title ?? "")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if player.currentEpisode != nil {
                VStack {
                    Slider(value: Binding(get: { player.currentTime },
                                          set: { player.seek(to: $0) }),
                           in: 0...player.totalTime)
                    HStack {
                        Text(fmt(player.currentTime)).font(.caption)
                        Spacer()
                        Text(fmt(player.totalTime)).font(.caption)
                    }
                }
            }
            HStack(spacing: 32) {
                Button { player.previous() } label: { Image(systemName: "backward.fill").font(.largeTitle) }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                Button { player.next() } label: { Image(systemName: "forward.fill").font(.largeTitle) }
            }
        }
        .padding()
    }

    @ViewBuilder private var image: some View {
        if let u = player.currentEpisode?.artworkURL {
            LazyImage(url: u) { s in
                if let img = s.image { img.resizable().scaledToFill() } else { Color.gray }
            }
        } else if let d = player.currentStation?.imageData, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let u = player.currentStation?.artworkURL {
            LazyImage(url: u) { s in
                if let img = s.image { img.resizable().scaledToFill() } else { Color.gray }
            }
        } else {
            Color.gray
        }
    }
}
