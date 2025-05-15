//
//  PodcastURLsTextFile.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import UniformTypeIdentifiers

struct PodcastURLsTextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    
    init(text: String = "") { self.text = text }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}
