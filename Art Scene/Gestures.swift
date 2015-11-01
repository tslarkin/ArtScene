//
//  Gestures.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/20/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

extension ArtSceneViewController
{
    override func magnifyWithEvent(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.1)
        let cameraNode = artSceneView.camera()
        let mag = Double(event.magnification) * 4
        cameraNode.camera!.xFov += mag
        cameraNode.camera!.yFov += mag
        updateCameraStatus()
    }
    
    override func rotateWithEvent(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.1)
        let cameraNode = artSceneView.camera()
        switch editMode {
        case .Normal:
            cameraNode.eulerAngles.y += CGFloat(event.rotation) / r2d
            let rot = cameraNode.eulerAngles.y * r2d
            let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
            status = "Camera Rotation: \(rot1)"
       case .WallPosition:
            targetWall?.eulerAngles.y += CGFloat(event.rotation) / r2d
            let angle = (targetWall!.eulerAngles.y * r2d) % 360.0
            let rotation = String(format: "%0.0f°", angle)
            status = "Wall Rotation: \(rotation)"
        default:
            break
        }
    }
    
    override func scrollWheel(event: NSEvent) {
        SCNTransaction.setAnimationDuration(0.3)
        let cameraNode = artSceneView.camera()
//        let angle = cameraNode.eulerAngles.y
        let dx = event.deltaX
        let dy = event.deltaY
        moveNode(dy, deltaRight: -dx, node: cameraNode)
//        var v = SCNVector3(x: sin(angle), y: 0.0, z: cos(angle))
//        var u = crossProduct(v, b: SCNVector3(0, 1, 0))
//        v.x *= dy
//        v.z *= dy
//        u.x *= -dx
//        u.z *= -dx
//        var position = cameraNode.position
//        position.x += v.x + u.x
//        position.z += v.z + u.z
//        cameraNode.position = position
        updateCameraStatus()
    }
}