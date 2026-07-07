import HotwireNative
import UIKit

/// Where your iKeep server lives. Over Tailscale this is something like
/// https://your-mac.your-tailnet.ts.net — see the README.
let rootURL = URL(string: ProcessInfo.processInfo.environment["IKEEP_URL"] ?? "http://localhost:3000")!

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let navigator = Navigator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigator.rootViewController
        window?.makeKeyAndVisible()

        navigator.route(rootURL)
    }
}
