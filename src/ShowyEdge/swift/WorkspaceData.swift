import AppKit
import Carbon
import CoreGraphics
import Foundation

@objc
public class WorkspaceData: NSObject {
  @objc
  public static let shared = WorkspaceData()
  @objc
  public static let fullScreenModeChanged = Notification.Name("fullScreenModeChanged")
  @objc
  public static let currentInputSourceChanged = Notification.Name("currentInputSourceChanged")

  var currentInputSourceID: String = ""
  var currentInputModeID: String = ""
  var menubarOrigins: Set<CGPoint> = []
  var activeSpaceDidChangeObserver: NSObjectProtocol?

  @objc
  public func start() {
    stop()

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(selectedKeyboardInputSourceChanged),
      name: kTISNotifySelectedKeyboardInputSourceChanged as NSNotification.Name?,
      object: nil,
      suspensionBehavior: .deliverImmediately
    )

    activeSpaceDidChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: OperationQueue.main,
      using: { [weak self] _ in
        guard let self = self else { return }

        self.updateMenubarOrigins()
      }
    )

    updateMenubarOrigins()
  }

  @objc
  public func stop() {
    DistributedNotificationCenter.default.removeObserver(self)

    if activeSpaceDidChangeObserver != nil {
      NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceDidChangeObserver!)
    }
  }

  @objc
  private func selectedKeyboardInputSourceChanged() {
    DispatchQueue.main.async {
      let inputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()

      self.currentInputSourceID = inputSource.inputSourceID ?? "unknown"
      self.currentInputModeID = inputSource.inputModeID ?? ""

      NotificationCenter.default.post(name: WorkspaceData.currentInputSourceChanged,
                                      object: nil)
    }
  }

  private func updateMenubarOrigins() {
    var menubarOrigins: Set<CGPoint> = []

    if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
      // We detect full screen spaces by checking if there's a menubar in the window list.
      // If not, we assume it's in fullscreen mode.
      for dict in windows {
        if dict["kCGWindowOwnerName"] as? String == "Window Server",
           dict["kCGWindowName"] as? String == "Menubar"
        {
          if let bounds = dict["kCGWindowBounds"] as? [String: Any],
             let x = bounds["X"] as? NSNumber,
             let y = bounds["Y"] as? NSNumber
          {
            menubarOrigins.insert(CGPoint(x: x.doubleValue,
                                          y: y.doubleValue))
          }
        }
      }

      if self.menubarOrigins != menubarOrigins {
        self.menubarOrigins = menubarOrigins

        NotificationCenter.default.post(name: WorkspaceData.fullScreenModeChanged,
                                        object: nil)
      }
    }
  }
}
