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
        SCNTransaction.animationDuration = 0.0
        let cameraNode = artSceneView.camera()
        let mag = CGFloat(event.magnification) * 4
        if #available(OSX 10.13, *)
        {
            cameraNode.camera?.fieldOfView += mag
        } else {
            cameraNode.camera?.xFov += Double(mag)
            cameraNode.camera?.yFov += Double(mag)
        }
        updateCameraStatus()
        hideGrids()
    }
    
    /// Rotate the camera or a wall with the rotation gesture.
    override func rotate(with event: NSEvent) {
        SCNTransaction.animationDuration = 0.0
        let cameraNode = artSceneView.camera()
        let omni = artSceneView.omniLight!
        let rotation = CGFloat(event.rotation) / 4.0
        cameraNode.eulerAngles.y = cameraNode.eulerAngles.y + rotation * 1 / r2d
        omni.eulerAngles.y = cameraNode.eulerAngles.y
        updateCameraStatus()
        hideGrids()
    }
    
    /// Move the camera according to the scroll wheel.
    override func scrollWheel(with event: NSEvent) {
        if event.deltaX == 0.0 && event.deltaY == 0.0 { return }
        SCNTransaction.animationDuration = 0.0
        let cameraNode = artSceneView.camera()
        let size = CGSize(width: event.deltaX / 20, height: event.deltaY / 20)
        let newPosition = newPositionFromAngle(cameraNode.position, deltaAway: size.height, deltaRight: -size.width, angle: cameraNode.yRotation)
        cameraNode.position = newPosition
        let omni = artSceneView.omniLight!
        omni.position = cameraNode.position
        updateCameraStatus()
        hideGrids()
    }
}
