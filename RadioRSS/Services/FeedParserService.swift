//
//  FeedParserService.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import Foundation
import FeedKit

struct FeedParserService {
    func parse(url: URL) async throws -> (title: String, artworkURL: URL?, episodes: [(title: String, audioURL: URL, artworkURL: URL?, pubDate: Date)]) {
        let parser = FeedParser(URL: url)
        let result = parser.parse()
        
        switch result {
        case .success(let feed):
            guard let rss = feed.rssFeed else { throw NSError(domain: "FeedParsing", code: -1) }
            let feedTitle = rss.title ?? url.lastPathComponent
            let feedArt = rss.iTunes?.iTunesImage?.attributes?.href.flatMap { URL(string: $0) }
            let items = rss.items ?? []
            let episodes = items.compactMap { item -> (String, URL, URL?, Date)? in
                guard
                    let enclosureURLString = item.enclosure?.attributes?.url,
                    let audioURL = URL(string: enclosureURLString)
                else { return nil }
                let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? audioURL.lastPathComponent
                let art = item.iTunes?.iTunesImage?.attributes?.href.flatMap { URL(string: $0) }
                let date = item.pubDate ?? Date()
                return (title, audioURL, art, date)
            }
                .sorted { $0.3 > $1.3 }
            return (feedTitle, feedArt, episodes)
        case .failure(let error):
            throw error
        }
    }
}
