//
//  ImportPodcastsFileView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportPodcastsFileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var importing = false
    @State private var busy = false
    @State private var processed = 0
    @State private var total = 0
    @State private var successes = 0
    @State private var failures = 0
    @State private var failedURLs: [String] = []
    @State private var showSummary = false
    @State private var errorMessage: String?

    private let descriptionText =
    """
    The .txt file must list one RSS feed URL on each line, for example:

    https://www.example.com/feed1
    https://www.example.com/feed2
    https://www.example.com/feed3
    """

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(descriptionText)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
                if busy || total > 0 {
                    VStack(alignment: .leading) {
                        if busy {
                            ProgressView(value: Double(processed), total: Double(max(total, 1)))
                        }
                        Text("\(processed)/\(total) processed – \(successes) succeeded – \(failures) failed")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            .navigationTitle("Import Podcasts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") { importing = true }.disabled(busy)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
                switch result {
                case .success(let url):
                    Task { await importFile(url) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showSummary) {
                NavigationStack {
                    List {
                        Section("Summary") {
                            Text("\(successes) succeeded")
                            Text("\(failures) failed")
                        }
                        if !failedURLs.isEmpty {
                            Section("Failed URLs") {
                                ForEach(failedURLs, id: \.self) { Text($0).textSelection(.enabled) }
                            }
                        }
                    }
                    .navigationTitle("Import Result")
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
                }
            }
            .alert(errorMessage ?? "",
                   isPresented: Binding(get: { errorMessage != nil },
                                        set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @MainActor
    private func importFile(_ fileURL: URL) async {
        var accessGranted = false
        if #available(iOS 15, *) { accessGranted = fileURL.startAccessingSecurityScopedResource() }
        defer { if accessGranted { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            busy = true
            let data = try Data(contentsOf: fileURL)
            guard let content = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Import", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Unable to decode file content"])
            }
            try await processContent(content)
            try context.save()
            busy = false
            showSummary = true
        } catch {
            busy = false
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func processContent(_ content: String) async throws {
        var lines = content.components(separatedBy: .newlines)
        lines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                     .filter { !$0.isEmpty }
        total = lines.count
        processed = 0
        successes = 0
        failures = 0
        failedURLs = []

        let existingFeeds = (try? context.fetch(FetchDescriptor<PodcastModel>())) ?? []
        var seen = Set(existingFeeds.map { $0.feedURL })

        for line in lines {
            processed += 1
            guard let feedURL = URL(string: line), !seen.contains(feedURL) else {
                failures += 1
                failedURLs.append(line)
                continue
            }
            seen.insert(feedURL)
            do {
                let (title, artworkURL, episodes) = try await FeedParserService().parse(url: feedURL)
                let podcast = PodcastModel(title: title, feedURL: feedURL, artworkURL: artworkURL)
                context.insert(podcast)
                for (t, au, art, date) in episodes {
                    let e = EpisodeModel(title: t, audioURL: au, artworkURL: art, pubDate: date, podcast: podcast)
                    podcast.episodes.append(e)
                }
                successes += 1
            } catch {
                failures += 1
                failedURLs.append(line)
            }
        }
    }
}
