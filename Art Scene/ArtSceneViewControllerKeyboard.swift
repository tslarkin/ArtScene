//
//  ArtSceneViewControllerKeyboard.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/18/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit
import Cocoa

extension ArtSceneViewController
{
    // MARK: Edit node position
    func registerUndos()
    {
        if (preparedForUndo == false ) { return }
        preparedForUndo = false
        guard let mouseNode = theNode else { return }
        document!.undoManager!.setActionName(actionName(mouseNode, editMode)!)
        switch editMode {
        case .resizing(.Picture, _):
            changePictureSize(mouseNode, from: saved as! CGSize, to: mouseNode.size()!)
        case .resizing(.Image, _):
            changeImageSize(mouseNode, from: saved as! CGSize, to: theImage(mouseNode).size()!)
        case .resizing(.Wall, _):
            let (oldSize, oldPosition, oldChildPositions) = saved as! (CGSize, SCNVector3, [SCNVector3])
            undoer.beginUndoGrouping()
            changeSize(mouseNode, from: oldSize, to: mouseNode.size()!)
            changePosition(mouseNode, from: oldPosition, to: mouseNode.position)
            let childen = mouseNode.childNodes.filter({ nodeType($0) == .Picture })
            let zipped = zip(childen, oldChildPositions)
            for (child, oldPosition) in zipped {
                let position = child.position
                changePosition(child, from: oldPosition, to: position)
            }
            undoer.endUndoGrouping()
        case .moving(.Picture):
            undoer.beginUndoGrouping()
           for (node, oldPosition, parent) in saved as! [(SCNNode, SCNVector3, SCNNode)] {
                let position = snapToGrid(node.position)
                changePosition(node, from: oldPosition, to: position)
                changeParent(node, from: parent, to: node.parent!)
            }
            undoer.endUndoGrouping()
       case .moving(.Wall):
            if !wallsLocked {
                let position = snapToGrid(mouseNode.position)
                changePosition(mouseNode, from: saved as! SCNVector3, to: position)
            }
        default:
            ()
        }
    }
    
    /// Edit the position of a picture or the selection using the arrow keys.
    func doFrameEditPosition(_ theEvent: NSEvent)
    {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode else { return }
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0 // ¼" or 1"
        var dx: CGFloat = 0, dy: CGFloat = 0
        let keyChar = Int(keyString[keyString.startIndex])
        switch keyChar {
        case NSRightArrowFunctionKey:
            dx = jump
        case NSLeftArrowFunctionKey:
            dx = -jump
        case NSUpArrowFunctionKey:
            dy = jump
        case NSDownArrowFunctionKey:
            dy = -jump
        default:
            return
        }
        let group = selection.contains(theNode) ? selection : [theNode]
        for picture in group {
            var position = picture.position
            position.x += dx
            position.y += dy
            picture.position = position
        }
        let (_, location, _, _) = pictureInfo(theNode)
        status = "Location: \(location)"
    }
    
    /// Edit the position of a wall using the arrow keys. If the command key is down, then
    /// use the left and right arrow keys to rotate the wall. If the shift key is down,
    /// use smaller deltas.
    func doWallEditPosition (_ theEvent: NSEvent)
    {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode else { return }
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 6.0
        let rotation: CGFloat = 5.01 / r2d
        let keyChar = Int(keyString[keyString.startIndex])
        SCNTransaction.animationDuration = 0.5
        if checkModifierFlags(theEvent, flag: .command) {
            var angle = theNode.yRotation
            switch keyChar {
            case NSLeftArrowFunctionKey:
                SCNTransaction.animationDuration = 0.2
                angle += rotation
            case NSRightArrowFunctionKey:
                SCNTransaction.animationDuration = 0.2
                angle -= rotation
            default:
                super.keyDown(with: theEvent)
            }
            theNode.yRotation = angle
        } else {
            var dz: CGFloat = 0.0
            var dx: CGFloat = 0.0
            switch keyChar {
            case NSUpArrowFunctionKey:
                dz = -jump
            case NSDownArrowFunctionKey:
                dz = jump
            case NSLeftArrowFunctionKey:
                dx = jump
            case NSRightArrowFunctionKey:
                dx = -jump
            default: break
            }
            let translate = simd_make_float3(Float(-dx), 0.0, Float(dz))
            theNode.simdLocalTranslate(by: translate)
        }
        let (_, location, rot, distance) = wallInfo(theNode, camera: artSceneView.camera())
        status = "Wall Position: \(location); Distance: \(distance!); Rotation: \(rot)"
    }
    
    /// Edit the size of the frame using the arrow keys. If the shift key is down, use smaller deltas.
    func doFrameEditSize(_ theEvent: NSEvent)
    {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode else { return }
        var size = theNode.size()!
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0 // ¼" or 3"
        let keyChar = Int(keyString[keyString.startIndex])
        switch keyChar {
        case NSRightArrowFunctionKey:
            size.width += jump
        case NSLeftArrowFunctionKey:
            size.width -= jump
        case NSUpArrowFunctionKey:
            size.height += jump
        case NSDownArrowFunctionKey:
            size.height -= jump
        default:
            return
        }
        reframePictureWithSize(theNode, newsize: size)
        let (newsize, _, _, _) = pictureInfo(theNode)
        status = "Picture: \(newsize)"
    }
    
    func doImageEditSize(_ theEvent: NSEvent)
    {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16 else { return }
        var size = theImage(theNode!).size()!
        let ratio = size.width / size.height
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0 // ¼" or 1"
        let keyChar = Int(keyString[keyString.startIndex])
        switch keyChar {
        case NSUpArrowFunctionKey:
            size.height += jump
        case NSDownArrowFunctionKey:
            size.height -= jump
        default:
            return
        }
        size.width = size.height * ratio
        reframeImageWithSize(theNode!, newsize: size)
        let (newsize, name) = imageInfo(theNode!)
        status = "\(name): \(newsize)"
    }
    
    /// Edit the size of a wall using the arrow keys. If the shift key is down, use smaller deltas.
    /// Ensure that the wall encloses all the pictures. If the option key is down, then
    /// wall size changes occur at the left side, otherwise on the right side
    /// If the wall height is changed, then the position has to be changed so the the
    /// bottom of the wall stays on the floor.
    // I could have saved myself a lot of trouble if I had known from the beginning
    // that I could change the point of origin of the node. On the other hand, the
    // default orientation makes rotation easy.
    func doWallEditSize(_ theEvent: NSEvent)
    {
        guard let theNode = theNode,
            let keyString = theEvent.charactersIgnoringModifiers?.utf16 else { return }
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 1 / 48.0 : 0.25 // ¼" or 3"
        let keyChar = Int(keyString[keyString.startIndex])
        var size = theNode.size()!
        var newsize = size
        var dx: CGFloat = 0.0
        var dy: CGFloat = 0.0
        switch keyChar {
        case NSUpArrowFunctionKey:
            dy = jump
        case NSDownArrowFunctionKey:
            newsize.height -= jump
            if wallContainsPictures(theNode, withNewSize: newsize) {
                dy = -jump
            }
        case NSRightArrowFunctionKey:
            dx = jump
        case NSLeftArrowFunctionKey:
            newsize.width -= jump
//            if wallContainsPictures(theNode, withNewSize: newsize) {
                dx = -jump
//            }
        default:
            super.keyDown(with: theEvent)
        }
        size.width += dx
        size.height += dy
        theNode.setSize(size)
        // In the default case, the wall shortens at the right side, and the left side
        // is fixed. The option key reverses this.
        let factor: Float = theEvent.modifierFlags.contains(.option) ? -1.0 : 1.0
        let translate = simd_make_float3(factor * Float(dx / 2.0), Float(dy / 2.0), 0.0)
        theNode.simdLocalTranslate(by: translate)
        for child in theNode.childNodes.filter({ nodeType($0) == .Picture }) {
            child.position.y -= dy / 2.0
            child.position.x -= dx / 2.0
        }
       defaultWallSize.height = size.height
        let info = wallInfo(theNode)
        status = "Wall Size: \(info.size)"
    }
    
    /// Change the location and rotation of the camera with the arrow keys. The rotation
    /// is changed if the command key is down.
    func doCameraEdit(_ theEvent: NSEvent) {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16 else { return }
        let charCode = Int(keyString[keyString.startIndex])
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let jump: CGFloat = shift ? 0.1 : 1.0
        let rotation: CGFloat = (shift ? 1.0 : 5.0) / r2d
        let cameraNode = artSceneView.camera()
        let omniLight = artSceneView.omniLight()
        SCNTransaction.animationDuration = 0.5
        let theFlags = theEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        let optionDown =  theFlags.contains(.option) && theFlags.subtracting([.option]).isEmpty
        let commandDown =  theFlags.contains(.command) && theFlags.subtracting([.command]).isEmpty
        if commandDown {
            var up: CGFloat = 0.0
            switch charCode {
            case NSUpArrowFunctionKey:
                up += jump
            case NSDownArrowFunctionKey:
                up -= jump
            default:
                super.keyDown(with: theEvent)
            }
            cameraNode.position.y += up
            omniLight.position = cameraNode.position
        } else if optionDown {
            switch charCode {
            case NSLeftArrowFunctionKey:
                cameraNode.yRotation += rotation
            case NSRightArrowFunctionKey:
                cameraNode.yRotation -= rotation
            case NSUpArrowFunctionKey:
                cameraNode.eulerAngles.x += rotation
            case NSDownArrowFunctionKey:
                cameraNode.eulerAngles.x -= rotation
            default:
                super.keyDown(with: theEvent)
            }
            omniLight.yRotation = cameraNode.yRotation
            omniLight.eulerAngles.x = cameraNode.eulerAngles.x
        } else {
            let angle = cameraNode.yRotation
            var v = SCNVector3(x: sin(angle) * jump, y: 0.0, z: cos(angle) * jump)
            let u = v × SCNVector3(0, 1, 0)
            // If the key is down arrow, we don't need to modify v
            switch charCode {
            case NSUpArrowFunctionKey:
                v.x *= -1.0
                v.z *= -1.0
            case NSLeftArrowFunctionKey:
                v = u
            case NSRightArrowFunctionKey:
                v = u
                v.x *= -1.0
                v.z *= -1.0
            default: break
            }
            var position = cameraNode.position
            position.x += v.x
            position.z += v.z
            cameraNode.position = position
            omniLight.position = position
        }
        updateCameraStatus()
    }
    
    @objc func beep(_ sender: AnyObject) {
        NSSound.beep()
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.tag == 0 {
            return true
        } else if undoer.canUndo {
            menuItem.title = "Undo \(undoer.undoActionName)"
            return true
        } else {
            menuItem.title = "Undo"
            return false
        }
    }
    
    @IBAction func undo(_ sender: AnyObject) {
        if preparedForUndo {
            NSSound.beep()
        } else {
            document!.undoManager!.undo()
        }
    }
    
    /// Dispatch the key down event on `editMode`.
    override func keyDown(with theEvent: NSEvent)
    {
        let pad = theEvent.modifierFlags.contains(.numericPad)
        guard let keyString = theEvent.charactersIgnoringModifiers else { return }
        if keyString == "+" {
            camera.fieldOfView += 2.0
            updateCameraStatus()
            return
        } else if keyString == "-" {
            camera.fieldOfView -= 2.0
            updateCameraStatus()
            return
        } else if pad {
            if case EditMode.none = editMode {
                doCameraEdit(theEvent)
            } else {
                guard let theNode = theNode else {
                    status = "No object!"
                    return
                }
                if !preparedForUndo {
                    prepareForUndo(theNode)
                    preparedForUndo = true
//                    setUndoMenuState(false)
                }
                
                switch editMode {
                case .moving(.Wall):
                    doWallEditPosition(theEvent)
                case .resizing(.Wall, _):
                    doWallEditSize(theEvent)
                case .resizing(.Picture, _):
                    doFrameEditSize(theEvent)
                case .resizing(.Image, _):
                    doImageEditSize(theEvent)
                case .moving(.Picture):
                    doFrameEditPosition(theEvent)
                default: ()
                }
            }
        } else {
            registerUndos()
        }
    }
}
