# iKeep for iOS — Hotwire Native shell

A thin native wrapper around the iKeep web app. The web views do all the
work; this shell gives you native navigation, a home-screen icon, and a
first-class feel.

## Build it

1. In Xcode: **File → New → Project → iOS App**. Name it `iKeep`,
   interface **Storyboard**, language **Swift**. Delete the generated
   `ViewController.swift`, `Main.storyboard`, `AppDelegate.swift` and
   `SceneDelegate.swift`.
2. Add the Hotwire Native package: **File → Add Package Dependencies…**
   and enter `https://github.com/hotwired/hotwire-native-ios` (1.x).
3. Drag `AppDelegate.swift` and `SceneDelegate.swift` from this directory
   into the project.
4. In the target's **Info** tab:
   - Remove the **Main storyboard file base name** entry.
   - Under **Application Scene Manifest → Scene Configuration →
     Application Session Role → Item 0**, remove the **Storyboard Name**
     entry.
5. Point the app at your server: edit `rootURL` in `SceneDelegate.swift`,
   or set an `IKEEP_URL` environment variable in your Xcode scheme.

## Reaching your server

- **Same Mac (simulator):** the default `http://localhost:3000` works
  as-is. Plain-HTTP localhost is allowed by App Transport Security.
- **Your phone over Tailscale (recommended):** install Tailscale on the
  iPhone, sign into your tailnet, and serve iKeep over HTTPS on the Mac:

      tailscale serve --bg 3000

  Then set `rootURL` to `https://your-mac.your-tailnet.ts.net`. Real
  HTTPS certificate, tailnet-only, no ATS exceptions needed, nothing
  exposed to the public internet.

## Notes

- Favorites drag-reorder uses HTML5 drag and drop, which is a desktop
  affordance; on the phone, pin/unpin from the thread header star.
- The web UI is styled with `-apple-system` fonts, safe-area-friendly
  layouts and dark mode, so it reads as native inside the shell.
