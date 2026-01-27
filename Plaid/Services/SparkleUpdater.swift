import SwiftUI
import Sparkle

@MainActor
final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()
    
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    
    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    
    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var updater = SparkleUpdater.shared
    
    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
