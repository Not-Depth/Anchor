#if !targetEnvironment(simulator)

import ARKit
import RealityKit
import SwiftUI

/// Live camera preview. RealityKit's ARView draws the camera feed; it adds no virtual
/// content. The view hands its ARSession to `onSessionReady`, and the depth controller
/// configures and runs it.
///
/// (ARSCNView would also work, but SceneKit is deprecated as of iOS 26.)
struct DepthCameraView: UIViewRepresentable {
    let onSessionReady: (ARSession) -> Void

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        onSessionReady(view.session)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        // Safety net: never leave the camera running after the preview disappears.
        uiView.session.pause()
    }
}

#endif
