//
//  PodcastModel.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import Foundation
import SwiftData

@Model
final class PodcastModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var feedURL: URL
    var artworkURL: URL?
    var episodes: [EpisodeModel]
    init(title: String, feedURL: URL, artworkURL: URL? = nil) {
        self.id = UUID()
        self.title = title
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.episodes = []
    }
}
