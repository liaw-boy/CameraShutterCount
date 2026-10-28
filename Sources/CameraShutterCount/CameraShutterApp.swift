import SwiftUI

@main
public struct CameraShutterApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 520, height: 560)
    }
}
