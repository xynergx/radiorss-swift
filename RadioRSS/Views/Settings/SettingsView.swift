//
//  SettingsView.swift
//  RadioRSS
//
//  Created by xynergx on 2025-05-15.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @State private var linkAlert = false
    @State private var resetAlert = false

    var body: some View {
        NavigationStack {
            List {
                Button("Reset Application") {
                    resetAlert = true
                }
                .foregroundColor(.red)
            }
            .navigationTitle("Settings")
            .alert("Delete all data?", isPresented: $resetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetApp() }
            }
        }
    }

    private func resetApp() {
        if let podcasts = try? context.fetch(FetchDescriptor<PodcastModel>()) {
            for p in podcasts { context.delete(p) }
        }
        if let stations = try? context.fetch(FetchDescriptor<StationModel>()) {
            for s in stations { context.delete(s) }
        }
        if let episodes = try? context.fetch(FetchDescriptor<EpisodeModel>()) {
            for e in episodes { context.delete(e) }
        }
        try? context.save()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
    }
}
