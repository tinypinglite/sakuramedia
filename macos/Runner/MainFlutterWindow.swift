import Cocoa
import FlutterMacOS

final class PassthroughVisualEffectView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

class MainFlutterWindow: NSWindow {
  private let flutterViewController = FlutterViewController()

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

    super.awakeFromNib()
  }
}
