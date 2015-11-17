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
    override func magnifyWithEvent(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.1)
        let cameraNode = artSceneView.camera()
        let mag = Double(event.magnification) * 4
        cameraNode.camera!.xFov += mag
        cameraNode.camera!.yFov += mag
        updateCameraStatus()
    }
    
    /// Rotate the camera or a wall with the rotation gesture.
    override func rotateWithEvent(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.1)
        let cameraNode = artSceneView.camera()
        switch editMode {
        case .None:
            cameraNode.eulerAngles.y += CGFloat(event.rotation) / r2d
            let rot = cameraNode.eulerAngles.y * r2d
            let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
            status = "Camera Rotation: \(rot1)"
       case .Resizing(.Wall, .Pivot):
            theNode?.eulerAngles.y += CGFloat(event.rotation) / r2d
            let angle = (theNode!.eulerAngles.y * r2d) % 360.0
            let rotation = String(format: "%0.0f°", angle)
            status = "Wall Rotation: \(rotation)"
        default:
            break
        }
    }
    
    /// Move the camera according to the scroll wheel.
    override func scrollWheel(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.3)
        let cameraNode = artSceneView.camera()
        let dx = event.deltaX
        let dy = event.deltaY
        moveNode(dy, deltaRight: -dx, node: cameraNode)
        updateCameraStatus()
    }
}