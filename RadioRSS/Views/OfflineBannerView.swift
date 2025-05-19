import SwiftUI

struct OfflineBannerView: View {
    @ObservedObject private var monitor = NetworkMonitor.shared

    var body: some View {
        if !monitor.isConnected {
            Text("No Internet Connection")
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .transition(.move(edge: .top))
                .allowsHitTesting(false)
                .zIndex(1)
        }
    }
}
