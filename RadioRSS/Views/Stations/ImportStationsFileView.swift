//
//  ImportStationsFileView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportStationsFileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var importing = false
    @State private var busy = false
    @State private var processed = 0
    @State private var total = 0
    @State private var successes = 0
    @State private var failures = 0
    @State private var failedLines: [String] = []
    @State private var showSummary = false
    @State private var errorMessage: String?

    private let descriptionText =
    """
    Provide a JSON file containing an array of objects:
    [
      {
        "title": "Example",
        "streamURL": "https://www.example.com/stream",
        "artworkURL": "https://www.example.com/artwork.png"
      }
    ]
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
            .navigationTitle("Import Station")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Import") { importing = true }.disabled(busy) }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
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
                        if !failedLines.isEmpty {
                            Section("Failed lines") {
                                ForEach(failedLines, id: \.self) { Text($0).textSelection(.enabled) }
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
    private func importFile(_ url: URL) async {
        var accessGranted = false
        if #available(iOS 15, *) { accessGranted = url.startAccessingSecurityScopedResource() }
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
        do {
            busy = true
            let data = try Data(contentsOf: url)
            try await importJSON(data)
            try context.save()
            busy = false
            showSummary = true
        } catch {
            busy = false
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func importJSON(_ data: Data) async throws {
        let records = try JSONDecoder().decode([StationImportModel].self, from: data)
        total = records.count
        processed = 0
        successes = 0
        failures = 0
        failedLines = []

        let existing = (try? context.fetch(FetchDescriptor<StationModel>())) ?? []
        var seen = Set(existing.map { $0.streamURL })

        for rec in records {
            processed += 1
            guard let stream = URL(string: rec.streamURL), !seen.contains(stream) else {
                failures += 1
                failedLines.append(rec.streamURL)
                continue
            }
            seen.insert(stream)
            let artwork = rec.artworkURL.flatMap { URL(string: $0) }
            context.insert(StationModel(title: rec.title,
                                 streamURL: stream,
                                 artworkURL: artwork,
                                 imageData: nil))
            successes += 1
        }
    }
}
