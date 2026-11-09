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
  private var windowAppearanceChannel: FlutterMethodChannel?
  private var visualEffectView: PassthroughVisualEffectView?

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
    self.visualEffectView = visualEffectView

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureExternalPlayerChannel()
    configureWindowAppearanceChannel()

    super.awakeFromNib()
    configureHiddenStandardWindowButtons()
  }

  /// 红绿灯由 Flutter 自绘（AppMacTrafficLights），系统按钮保持隐藏：
  /// window_manager 的 `windowButtonVisibility: false` 已完成首次隐藏，
  /// 但全屏切换会重建标题栏，进出全屏后再兜底隐藏一次，避免系统悬浮
  /// 标题栏里出现原生按钮与自绘圆点重复。
  private func configureHiddenStandardWindowButtons() {
    hideStandardWindowButtons()
    for name in [
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
    ] {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleFullScreenTransition),
        name: name,
        object: self
      )
    }
  }

  @objc private func handleFullScreenTransition(_ notification: Notification) {
    DispatchQueue.main.async { [weak self] in
      self?.hideStandardWindowButtons()
    }
  }

  private func hideStandardWindowButtons() {
    let types: [NSWindow.ButtonType] = [
      .closeButton, .miniaturizeButton, .zoomButton,
    ]
    for type in types {
      standardWindowButton(type)?.isHidden = true
    }
  }

  private func configureWindowAppearanceChannel() {
    let channel = FlutterMethodChannel(
      name: "sakuramedia/window_appearance",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setAppearance" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let dark = arguments["dark"] as? Bool
      else {
        result(
          FlutterError(code: "invalid_arguments", message: "缺少 dark 参数", details: nil)
        )
        return
      }
      self?.applyWindowAppearance(
        dark: dark,
        windowVibrancy: arguments["windowVibrancy"] as? Bool ?? true,
        backgroundColor: (arguments["backgroundColor"] as? NSNumber)?.intValue
      )
      result(nil)
    }
    windowAppearanceChannel = channel
  }

  /// 窗口毛玻璃是独立于 Flutter 表面风格的偏好；关闭时窗口改为不透明，
  /// 由 Dart 侧传入当前主题的页面底色兜底。
  private func applyWindowAppearance(
    dark: Bool,
    windowVibrancy: Bool,
    backgroundColor: Int?
  ) {
    // 毛玻璃跟随应用内主题，而不是系统外观；否则浅色应用 + 深色系统时
    // 侧栏玻璃会与 Flutter 内容脱节。
    visualEffectView?.appearance = NSAppearance(
      named: dark ? .darkAqua : .aqua
    )
    visualEffectView?.state = windowVibrancy ? .active : .inactive
    visualEffectView?.isHidden = !windowVibrancy

    if windowVibrancy {
      isOpaque = false
      self.backgroundColor = .clear
    } else {
      self.backgroundColor = Self.color(fromARGB: backgroundColor ?? 0xFF1E1E1E)
      isOpaque = true
    }
    invalidateShadow()
  }

  private static func color(fromARGB argb: Int) -> NSColor {
    let alpha = CGFloat((argb >> 24) & 0xFF) / 255
    let red = CGFloat((argb >> 16) & 0xFF) / 255
    let green = CGFloat((argb >> 8) & 0xFF) / 255
    let blue = CGFloat(argb & 0xFF) / 255
    return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
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
