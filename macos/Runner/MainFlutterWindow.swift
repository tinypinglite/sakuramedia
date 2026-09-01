import Cocoa
import CoreServices
import FlutterMacOS

final class PassthroughVisualEffectView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

class MainFlutterWindow: NSWindow {
  private static let iinaBundleIdentifier = "com.colliderli.iina"
  private static let vlcBundleIdentifier = "org.videolan.vlc"
  private static let infuseBundleIdentifier = "com.firecore.infuse"
  private static let externalPlayerBundleIdentifiers: Set<String> = [
    "org.videolan.vlc",
    "com.colliderli.iina",
    "io.mpv",
    "com.firecore.infuse",
  ]

  private let flutterViewController = FlutterViewController()
  private var externalPlayerChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let windowFrame = self.frame
    flutterViewController.backgroundColor = .clear

    self.isOpaque = false
    self.backgroundColor = .clear
    self.titlebarAppearsTransparent = true
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let wrapperView = flutterViewController.view
    let visualEffectView = PassthroughVisualEffectView(frame: wrapperView.bounds)
    visualEffectView.autoresizingMask = [.width, .height]
    visualEffectView.material = .sidebar
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    wrapperView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureExternalPlayerChannel()

    super.awakeFromNib()
  }

  private func configureExternalPlayerChannel() {
    let channel = FlutterMethodChannel(
      name: "sakuramedia/external_player",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      switch call.method {
      case "listPlayers":
        result(self.listPlayers())
      case "launch":
        self.launchPlayer(arguments: call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    externalPlayerChannel = channel
  }

  private func listPlayers() -> [[String: String]] {
    let sampleFile = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("m3u8")
    FileManager.default.createFile(atPath: sampleFile.path, contents: Data())
    defer {
      try? FileManager.default.removeItem(at: sampleFile)
    }

    let applications = applicationsForM3u8(sampleFile: sampleFile)
    let ownApplicationURL = Bundle.main.bundleURL.standardizedFileURL
    return applications
      .filter { applicationURL in
        guard
          applicationURL.standardizedFileURL != ownApplicationURL,
          let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier
        else {
          return false
        }
        return Self.externalPlayerBundleIdentifiers.contains(bundleIdentifier)
      }
      .map { applicationURL in
        [
          "id": applicationURL.path,
          "label": FileManager.default.displayName(atPath: applicationURL.path),
        ]
      }
  }

  private func applicationsForM3u8(sampleFile: URL) -> [URL] {
    if #available(macOS 12.0, *) {
      return NSWorkspace.shared.urlsForApplications(toOpen: sampleFile)
    }
    guard
      let contentType = UTTypeCreatePreferredIdentifierForTag(
        kUTTagClassFilenameExtension,
        "m3u8" as CFString,
        nil
      )?.takeRetainedValue(),
      let bundleIdentifiers = LSCopyAllRoleHandlersForContentType(
        contentType,
        .all
      )?.takeRetainedValue() as? [String]
    else {
      return []
    }
    return bundleIdentifiers.compactMap {
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
    }
  }

  private func launchPlayer(arguments: Any?, result: @escaping FlutterResult) {
    guard
      let arguments = arguments as? [String: Any],
      let playerId = arguments["playerId"] as? String,
      let urlString = arguments["url"] as? String,
      let streamURL = URL(string: urlString),
      let scheme = streamURL.scheme?.lowercased(),
      scheme == "http" || scheme == "https"
    else {
      result(FlutterError(code: "invalid_arguments", message: "缺少有效播放参数", details: nil))
      return
    }

    let applicationURL = URL(fileURLWithPath: playerId)
    guard FileManager.default.fileExists(atPath: applicationURL.path) else {
      result(false)
      return
    }

    let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier
    if bundleIdentifier == Self.iinaBundleIdentifier {
      var components = URLComponents()
      components.scheme = "iina"
      components.host = "open"
      components.queryItems = [
        URLQueryItem(name: "url", value: streamURL.absoluteString),
      ]
      guard let iinaURL = components.url else {
        result(false)
        return
      }
      NSWorkspace.shared.open(
        iinaURL,
        configuration: NSWorkspace.OpenConfiguration()
      ) { _, error in
        result(error == nil)
      }
      return
    }

    if bundleIdentifier == Self.vlcBundleIdentifier {
      launchVLC(
        applicationURL: applicationURL,
        streamURL: streamURL,
        result: result
      )
      return
    }

    if bundleIdentifier == Self.infuseBundleIdentifier {
      launchInfuse(
        streamURL: streamURL,
        title: arguments["title"] as? String,
        positionMs: arguments["positionMs"] as? Int,
        result: result
      )
      return
    }

    NSWorkspace.shared.open(
      [streamURL],
      withApplicationAt: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, error in
      result(error == nil)
    }
  }

  private func launchVLC(
    applicationURL: URL,
    streamURL: URL,
    result: @escaping FlutterResult
  ) {
    let playlistURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("m3u")
    let playlistData = Data("#EXTM3U\n\(streamURL.absoluteString)\n".utf8)
    guard FileManager.default.createFile(
      atPath: playlistURL.path,
      contents: playlistData,
      attributes: [.posixPermissions: NSNumber(value: 0o600)]
    ) else {
      result(false)
      return
    }

    NSWorkspace.shared.open(
      [playlistURL],
      withApplicationAt: applicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, error in
      result(error == nil)
      DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
        try? FileManager.default.removeItem(at: playlistURL)
      }
    }
  }

  private func launchInfuse(
    streamURL: URL,
    title: String?,
    positionMs: Int?,
    result: @escaping FlutterResult
  ) {
    var components = URLComponents()
    components.scheme = "infuse"
    components.host = "x-callback-url"
    components.path = "/play"
    var queryItems = [URLQueryItem(name: "url", value: streamURL.absoluteString)]
    if let title, !title.isEmpty {
      queryItems.append(URLQueryItem(name: "filename", value: title))
    }
    if let positionMs, positionMs > 0 {
      queryItems.append(
        URLQueryItem(name: "position", value: String(positionMs / 1000))
      )
    }
    components.queryItems = queryItems
    guard let infuseURL = components.url else {
      result(false)
      return
    }

    NSWorkspace.shared.open(
      infuseURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, error in
      result(error == nil)
    }
  }
}
