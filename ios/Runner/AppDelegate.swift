import Flutter
import UIKit
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  var pipController: AVPictureInPictureController?
  var pipPlayer: AVPlayer?
  var pipLayer: AVPlayerLayer?
  var pipHostView: UIView?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "app.pip", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "enterPip":
          guard let args = call.arguments as? [String: Any],
                let urlString = args["url"] as? String,
                let url = URL(string: urlString) else {
            result(FlutterError(code: "ARG_ERROR", message: "Missing URL", details: nil))
            return
          }
          let headers = args["headers"] as? [String: String] ?? [:]
          self.startPiP(url: url, headers: headers)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startPiP(url: URL, headers: [String: String]) {
    let options = ["AVURLAssetHTTPHeaderFieldsKey": headers]
    let asset = AVURLAsset(url: url, options: options)
    let item = AVPlayerItem(asset: asset)
    pipPlayer = AVPlayer(playerItem: item)
    pipLayer = AVPlayerLayer(player: pipPlayer)
    pipLayer?.videoGravity = .resizeAspect

    if let root = window?.rootViewController?.view {
      let host = UIView(frame: .zero)
      host.isHidden = true
      root.addSubview(host)
      pipHostView = host
      if let layer = pipLayer {
        layer.frame = .zero
        host.layer.addSublayer(layer)
      }
    }

    if AVPictureInPictureController.isPictureInPictureSupported(), let layer = pipLayer {
      pipController = AVPictureInPictureController(playerLayer: layer)
      if #available(iOS 14.2, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
      }
      pipPlayer?.play()
      pipController?.startPictureInPicture()
    }
  }
}
