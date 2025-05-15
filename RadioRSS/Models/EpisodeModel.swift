//
//  EpisodeModel.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import Foundation
import SwiftData

@Model
final class EpisodeModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var audioURL: URL
    var artworkURL: URL?
    var pubDate: Date
    var duration: Double?
    var localFileURL: URL?
    var progress: Double
    var podcast: PodcastModel?
    init(title: String, audioURL: URL, artworkURL: URL? = nil, pubDate: Date = Date(), duration: Double? = nil, podcast: PodcastModel? = nil) {
        self.id = UUID()
        self.title = title
        self.audioURL = audioURL
        self.artworkURL = artworkURL
        self.pubDate = pubDate
        self.duration = duration
        self.localFileURL = nil
        self.progress = 0
        self.podcast = podcast
    }
}
