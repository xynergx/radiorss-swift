//
//  ImportStationsURLView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData

struct ImportStationsURLView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var remoteURLText = ""
    @State private var busy = false
    @State private var processed = 0
    @State private var total = 0
    @State private var successes = 0
    @State private var failures = 0
    @State private var failedLines: [String] = []
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
            .navigationTitle("Import Stations")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
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
    private func importRemote() async {
        guard let url = URL(string: remoteURLText) else { return }
        do {
            busy = true
            let (data, _) = try await URLSession.shared.data(from: url)
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
    private func importJSON(_ data: Data) async throws {
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
