//
//  StationModel.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import Foundation
import SwiftData

@Model
final class StationModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var streamURL: URL
    var artworkURL: URL?
    var imageData: Data?
    init(title: String,
         streamURL: URL,
         artworkURL: URL? = nil,
         imageData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.streamURL = streamURL
        self.artworkURL = artworkURL
        self.imageData = imageData
    }
}
