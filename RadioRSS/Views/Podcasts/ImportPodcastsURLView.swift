//
//  ImportPodcastsURLView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData

struct ImportPodcastsURLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var remoteURLText = ""
    @State private var busy = false
    @State private var processed = 0
    @State private var total = 0
    @State private var successes = 0
    @State private var failures = 0
    @State private var failedURLs: [String] = []
    @State private var showSummary = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("URL", text: $remoteURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    Button("Import") { Task { await importRemote() } }
                        .disabled(remoteURLText.isEmpty || busy)
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
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
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
    private func importRemote() async {
        guard let url = URL(string: remoteURLText) else { return }
        do {
            busy = true
            let (data, _) = try await URLSession.shared.data(from: url)
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
