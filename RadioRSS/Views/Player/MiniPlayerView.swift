//
//  MiniPlayerView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import NukeUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerViewModel

    var body: some View {
        if player.currentEpisode != nil || player.currentStation != nil {
            VStack(spacing: 8) {
                Divider()
                HStack {
                    artwork
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(player.currentEpisode?.title ?? player.currentStation?.title ?? "")
                        .lineLimit(1)
                    Spacer()
                    Button { player.toggle() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
                .onTapGesture { present() }
                Divider()
            }
            .background(.thickMaterial)
        }
    }

    @ViewBuilder private var artwork: some View {
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

    private func present() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(UIHostingController(rootView: PlayerView().environmentObject(player)), animated: true)
        }
    }
}
