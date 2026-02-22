import SwiftUI

@main
struct QuickCaptureLiteApp: App {
    // The app owns a single controller that encapsulates all DAT state
    @StateObject private var controller = QuickCaptureController()

    var body: some Scene {
        WindowGroup {
            // Inject the controller into the SwiftUI view hierarchy
            QuickCaptureView(controller: controller)
        }
    }
}
