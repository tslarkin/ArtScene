//
//  Gestures.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/20/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

/**
 An extension to support operations based on track pad gestures.
*/
extension ArtSceneViewController
{
    /// Change the camera's field of view with the magnify gesture.
    override func magnify(with event: NSEvent) {
        SCNTransaction.animationDuration = 0.1
        let cameraNode = artSceneView.camera()
        let mag = CGFloat(event.magnification) * 4
        cameraNode.camera?.fieldOfView += mag
        updateCameraStatus()
    }
    
    /// Rotate the camera or a wall with the rotation gesture.
    override func rotate(with event: NSEvent) {
        SCNTransaction.animationDuration = 0.0
        let cameraNode = artSceneView.camera()
        let omni = artSceneView.omniLight()
        let rotation = CGFloat(event.rotation)
        cameraNode.eulerAngles.y = cameraNode.eulerAngles.y + rotation * 1 / r2d
        omni.eulerAngles.y = cameraNode.eulerAngles.y
        let rot = (cameraNode.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
        status = "Camera Rotation: \(rot1)"

//        switch editMode {
//        case .none:
//            let rotation = CGFloat(event.rotation)
//            cameraNode.eulerAngles.y = cameraNode.eulerAngles.y + rotation * 1 / r2d
//            omni.eulerAngles.y = cameraNode.eulerAngles.y
//            let rot = (cameraNode.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
//            let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
//            status = "Camera Rotation: \(rot1)"
//       case .resizing(.Wall, .pivot):
//            theNode?.eulerAngles.y += snapToGrid(CGFloat(event.rotation)) / r2d / 10
//            let angle = (theNode!.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
//            let rotation = String(format: "%0.0f°", angle)
//            status = "Wall Rotation: \(rotation)"
//        default:
//            break
//        }
    }
    
    /// Move the camera according to the scroll wheel.
    override func scrollWheel(with event: NSEvent) {
        SCNTransaction.animationDuration = 0.3
        let cameraNode = artSceneView.camera()
        let size = snapToGrid(CGSize(width: event.deltaX / 20, height: event.deltaY / 20))
        moveNode(size.height, deltaRight: -size.width, node: cameraNode, angle: cameraNode.eulerAngles.y)
        let omni = artSceneView.omniLight()
        omni.position = cameraNode.position
        updateCameraStatus()
    }
}
