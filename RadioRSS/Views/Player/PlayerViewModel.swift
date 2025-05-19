//
//  PlayerViewModel.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import Foundation
import AVFoundation
import SwiftData
import MediaPlayer
import UIKit
import Combine
import Nuke

@MainActor
final class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()
    private static let artworkCache = NSCache<NSURL, UIImage>()
    private let player = AVPlayer()
    @Published var currentEpisode: EpisodeModel?
    @Published var currentStation: StationModel?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 1
    @Published var networkAlert: String?
    private var playlist: [EpisodeModel] = []
    private var timeObserver: Any?
    private var endObserver: Any?
    private var stallObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var cancellable: AnyCancellable?
    private var pendingEpisode: EpisodeModel?
    private var pendingStation: StationModel?
    private var lostConnection = false
    private var autoPausedForBuffer = false

    private init() {
        configureRemoteCommands()
        observeNetwork()
        observePlayerStatus()
    }

    private func observeNetwork() {
        cancellable = NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.handleNetworkChange(connected)
            }
    }

    private func observePlayerStatus() {
        statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            guard let self else { return }
            Task { @MainActor in
                switch p.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.autoPausedForBuffer = false
                case .paused, .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                @unknown default:
                    self.isPlaying = false
                }
                self.updateNowPlaying()
            }
        }
    }

    private func handleNetworkChange(_ connected: Bool) {
        if connected {
            if autoPausedForBuffer, currentStation != nil {
                autoPausedForBuffer = false
                if let r = currentStation {
                    let item = AVPlayerItem(url: r.streamURL)
                    player.replaceCurrentItem(with: item)
                    player.play()
                }
                return
            }
            if pendingEpisode != nil || pendingStation != nil {
                if let ep = pendingEpisode {
                    let list = playlist.isEmpty ? [ep] : playlist
                    pendingEpisode = nil
                    play(episode: ep, playlist: list)
                } else if let r = pendingStation {
                    pendingStation = nil
                    play(station: r)
                }
                return
            }
            if lostConnection && player.timeControlStatus != .playing {
                if let r = currentStation {
                    let item = AVPlayerItem(url: r.streamURL)
                    player.replaceCurrentItem(with: item)
                }
                player.play()
            }
            lostConnection = false
        } else {
            lostConnection = true
        }
    }

    func play(episode: EpisodeModel, playlist override: [EpisodeModel]? = nil) {
        autoPausedForBuffer = false
        if !NetworkMonitor.shared.isConnected {
            networkAlert = "No Internet Connection"
            pendingEpisode = episode
            pendingStation = nil
            return
        }

        currentStation = nil
        currentEpisode = episode

        if let override {
            playlist = override
        } else if let eps = episode.podcast?.episodes {
            playlist = eps.sorted { $0.pubDate > $1.pubDate }
        } else {
            playlist = [episode]
        }

        let url = episode.audioURL
        var start = episode.progress
        if let dur = episode.duration, dur - start <= 10 {
            start = 0
            episode.progress = 0
            try? episode.modelContext?.save()
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                             object: item,
                                                             queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let ep = self.currentEpisode,
                   let idx = self.playlist.firstIndex(of: ep),
                   idx + 1 < self.playlist.count {
                    self.play(episode: self.playlist[idx + 1], playlist: self.playlist)
                } else {
                    self.player.pause()
                    self.isPlaying = false
                    self.updateNowPlaying()
                }
            }
        }

        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
            self.stallObserver = nil
        }

        if start > 0 {
            player.seek(to: CMTime(seconds: start, preferredTimescale: 1))
        }
        currentTime = start
        player.play()
        totalTime = episode.duration ?? 1
        observeDuration(for: item, episode: episode)
        observeProgress()
    }

    func play(station: StationModel) {
        autoPausedForBuffer = false
        if !NetworkMonitor.shared.isConnected {
            networkAlert = "No Internet Connection"
            pendingStation = station
            pendingEpisode = nil
            currentStation = station
            return
        }

        currentEpisode = nil
        currentStation = station

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let stallObserver {
            NotificationCenter.default.removeObserver(stallObserver)
            self.stallObserver = nil
        }

        let item = AVPlayerItem(url: station.streamURL)
        stallObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled,
                                                               object: item,
                                                               queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackStalled()
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()

        currentTime = 0
        totalTime = 1
        removeObserver()
    }

    private func handlePlaybackStalled() {
        guard currentStation != nil else { return }
        guard !autoPausedForBuffer else { return }
        guard !NetworkMonitor.shared.isConnected else { return }
        autoPausedForBuffer = true
        player.pause()
    }

    func toggle() {
        if isPlaying {
            player.pause()
            autoPausedForBuffer = false
        } else {
            if !NetworkMonitor.shared.isConnected && currentStation != nil && pendingStation == nil {
                networkAlert = "No Internet Connection"
                if let r = currentStation { pendingStation = r }
                return
            }
            player.play()
            autoPausedForBuffer = false
        }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1))
        if let ep = currentEpisode {
            ep.progress = seconds
            try? ep.modelContext?.save()
        }
        currentTime = seconds
        updateNowPlaying()
    }

    func next() {
        guard let ep = currentEpisode,
              let idx = playlist.firstIndex(of: ep),
              idx + 1 < playlist.count else { return }
        play(episode: playlist[idx + 1], playlist: playlist)
    }

    func previous() {
        guard let ep = currentEpisode,
              let idx = playlist.firstIndex(of: ep),
              idx - 1 >= 0 else { return }
        play(episode: playlist[idx - 1], playlist: playlist)
    }

    private func observeDuration(for item: AVPlayerItem, episode: EpisodeModel) {
        Task {
            let sec = (try? await item.asset.load(.duration).seconds) ?? 0
            guard sec.isFinite, sec > 0 else { return }
            totalTime = sec
            if episode.duration == nil || episode.duration != sec {
                episode.duration = sec
                try? episode.modelContext?.save()
            }
            updateNowPlaying()
        }
    }

    private func observeProgress() {
        removeObserver()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1),
                                                      queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                if let ep = self.currentEpisode {
                    ep.progress = self.currentTime
                    try? ep.modelContext?.save()
                }
                self.updateNowPlaying()
            }
        }
    }

    private func removeObserver() {
        if let obs = timeObserver {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
    }

    private func configureRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent,
                  let s = self,
                  s.currentEpisode != nil else { return .commandFailed }
            s.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]

        if let ep = currentEpisode {
            info[MPMediaItemPropertyTitle] = ep.title
            if let artURL = ep.artworkURL {
                if let img = Self.artworkCache.object(forKey: artURL as NSURL) {
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                } else if artURL.isFileURL, let img = UIImage(contentsOfFile: artURL.path) {
                    Self.artworkCache.setObject(img, forKey: artURL as NSURL)
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                } else {
                    Task.detached { [artURL] in
                        if let img = try? await ImagePipeline.shared.image(for: artURL) {
                            await MainActor.run { [weak self] in
                                Self.artworkCache.setObject(img, forKey: artURL as NSURL)
                                guard let self, self.currentEpisode?.artworkURL == artURL else { return }
                                self.updateNowPlaying()
                            }
                        }
                    }
                }
            }
            info[MPMediaItemPropertyPlaybackDuration] = totalTime
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        } else if let r = currentStation {
            info[MPMediaItemPropertyTitle] = r.title
            if let d = r.imageData, let img = UIImage(data: d) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            } else if let artURL = r.artworkURL {
                if let img = Self.artworkCache.object(forKey: artURL as NSURL) {
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                } else if artURL.isFileURL, let img = UIImage(contentsOfFile: artURL.path) {
                    Self.artworkCache.setObject(img, forKey: artURL as NSURL)
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                } else {
                    Task.detached { [artURL] in
                        if let img = try? await ImagePipeline.shared.image(for: artURL) {
                            await MainActor.run { [weak self] in
                                Self.artworkCache.setObject(img, forKey: artURL as NSURL)
                                guard let self, self.currentStation?.artworkURL == artURL else { return }
                                self.updateNowPlaying()
                            }
                        }
                    }
                }
            }
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
        }

        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
