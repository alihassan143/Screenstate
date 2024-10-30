import AppKit
import Cocoa
import CoreGraphics
import FlutterMacOS

public class DesktopScreenstatePlugin: NSObject, FlutterPlugin {
  var keyEventMonitor: Any?
  var mouseEventMonitor: Any?
  var inactivityMouseTimer: Timer?
  var inactivityKeyboardTimer: Timer?
  let inactivityDuration: TimeInterval = 5.0
  var eventHandler: GlobalEventMonitor?
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screenstate", binaryMessenger: registrar.messenger)
    let instance = DesktopScreenstatePlugin(channel)
    registrar.addMethodCallDelegate(instance, channel: channel)

  }

  private let channel: FlutterMethodChannel

  public init(_ channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(screenDidSleep), name: NSWorkspace.willSleepNotification,
      object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(screenDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    let center = DistributedNotificationCenter.default()
    center.addObserver(
      self, selector: #selector(screenIsLocked),
      name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
    center.addObserver(
      self, selector: #selector(screenIsUnlocked),
      name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
    setupEventListeners()
  }

  @objc func screenIsLocked() {
    dispatchApplicationState(active: "locked")
  }

  @objc func screenIsUnlocked() {
    dispatchApplicationState(active: "unlocked")
  }

  @objc func screenDidSleep() {
    dispatchApplicationState(active: "sleep")
  }

  @objc func screenDidWake() {
    dispatchApplicationState(active: "awaked")
  }

  private func dispatchApplicationState(active: String) {
    channel.invokeMethod("onScreenStateChange", arguments: active)
  }

  private func dispatchMouseApplicationState(active: String) {
    channel.invokeMethod("mouseState", arguments: active)
  }

  private func dispatchKeyboardApplicationState(active: String) {
    channel.invokeMethod("keyboardState", arguments: active)
  }

  private func setupEventListeners() {
    eventHandler = GlobalEventMonitor(
      mask: [.mouseMoved, .leftMouseUp, .rightMouseDown, .flagsChanged, .keyDown],
      handler: { (event: NSEvent?) in

        switch event?.type {
        case .flagsChanged:
          self.resetKeyboardInactivityTimer()
          self.dispatchKeyboardApplicationState(active: "active")
        case .keyDown:
          self.resetKeyboardInactivityTimer()
          self.dispatchKeyboardApplicationState(active: "active")
        case .mouseMoved, .leftMouseUp, .rightMouseDown:
          self.resetMouseInactivityTimer()
          self.dispatchMouseApplicationState(active: "active")
        default:
          break

        }

      })
    eventHandler?.start()

    resetMouseInactivityTimer()
    resetKeyboardInactivityTimer()
  }

  private func resetMouseInactivityTimer() {
    inactivityMouseTimer?.invalidate()  // Cancel any existing timer
    inactivityMouseTimer = Timer.scheduledTimer(
      timeInterval: inactivityDuration, target: self, selector: #selector(setMouseInactive),
      userInfo: nil, repeats: false)
  }

  @objc private func setMouseInactive() {
    dispatchMouseApplicationState(active: "inactive")  // Mark as inactive if no mouse events detected for a while
  }

  private func resetKeyboardInactivityTimer() {
    inactivityKeyboardTimer?.invalidate()  // Cancel any existing timer
    inactivityKeyboardTimer = Timer.scheduledTimer(
      timeInterval: inactivityDuration, target: self, selector: #selector(setKeyboardInactive),
      userInfo: nil, repeats: false)
  }

  @objc private func setKeyboardInactive() {
    dispatchKeyboardApplicationState(active: "inactive")  // Mark as inactive if no keyboard events detected for a while
  }

}

public class GlobalEventMonitor {

  private var monitor: AnyObject?
  private let mask: NSEvent.EventTypeMask
  private let handler: (NSEvent?) -> Void

  public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
    self.mask = mask
    self.handler = handler
  }

  deinit {
    stop()
  }

  public func start() {
    monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as AnyObject?
  }

  public func stop() {
    if monitor != nil {
      NSEvent.removeMonitor(monitor!)
      monitor = nil
    }
  }
}
