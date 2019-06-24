//
//  ArtSceneViewControllerKeyboard.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/18/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit
import Cocoa

extension ArtSceneViewController
{
    // MARK: Edit node position

    
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
        case NSEvent.SpecialKey.rightArrow.rawValue:
            dx = jump
        case NSEvent.SpecialKey.leftArrow.rawValue:
            dx = -jump
        case NSEvent.SpecialKey.upArrow.rawValue:
            dy = jump
        case NSEvent.SpecialKey.downArrow.rawValue:
            dy = -jump
        default:
            return
        }
        let group = selection.contains(theNode) ? selection : [theNode]
        let translation = SCNVector3Make(dx, dy, 0.0)
        for picture in group {
            changePosition(picture, delta: translation)
        }
        
        let (x, y, _, _, _, _) = pictureInfo(theNode)
        hudUpdate = makeDisplay(title: "Picture",
                                     items: [("↔", x), ("↕", y)],
                                     width: fontScaler * 150)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
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
        SCNTransaction.animationDuration = 0.0
        if checkModifierFlags(theEvent, flag: .option) {
            var angle = theNode.yRotation
            switch keyChar {
            case NSEvent.SpecialKey.leftArrow.rawValue:
                SCNTransaction.animationDuration = 0.0
                angle += rotation
            case NSEvent.SpecialKey.rightArrow.rawValue:
                SCNTransaction.animationDuration = 0.0
                angle -= rotation
            default:
                super.keyDown(with: theEvent)
            }
            changePivot(theNode, delta: angle - theNode.yRotation)
        } else {
            var dz: CGFloat = 0.0
            var dx: CGFloat = 0.0
            switch keyChar {
            case NSEvent.SpecialKey.upArrow.rawValue:
                dz = -jump
            case NSEvent.SpecialKey.downArrow.rawValue:
                dz = jump
            case NSEvent.SpecialKey.leftArrow.rawValue:
                dx = -jump
            case NSEvent.SpecialKey.rightArrow.rawValue:
                dx = jump
            default: break
            }
            changePosition(theNode, delta: SCNVector3Make(dx, 0.0, dz))
        }
        hideGrids()
        let (x, z, _, _, rot, distance) = wallInfo(theNode, camera: artSceneView.camera())
        hudUpdate = makeDisplay(title: "Wall", items: [("↔", x), ("↕", z), ("y°", rot), ("↑", distance!)], width: fontScaler * 175)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
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
        case NSEvent.SpecialKey.rightArrow.rawValue:
            size.width += jump
        case NSEvent.SpecialKey.leftArrow.rawValue:
            size.width -= jump
        case NSEvent.SpecialKey.upArrow.rawValue:
            size.height += jump
        case NSEvent.SpecialKey.downArrow.rawValue:
            size.height -= jump
        default:
            return
        }
        if size.width < minimumPictureSize || size.height < minimumPictureSize { return }
        changePictureSize(theNode, to: size)
        let (_, _, width, height, _, _) = pictureInfo(theNode)
        hudUpdate = makeDisplay(title: "Picture",
                                     items: [("width", width), ("height", height)])
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
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
        case NSEvent.SpecialKey.upArrow.rawValue:
            size.height += jump
        case NSEvent.SpecialKey.downArrow.rawValue:
            size.height -= jump
        default:
            return
        }
        size.width = size.height * ratio
        if size.height < minimumImageSize || size.width < minimumImageSize { return }
        changeImageSize(theNode!, to: size)
        
        let (width, height, name) = imageInfo(theNode!)
        hudUpdate = makeDisplay(title: name,
                                     items: [("width", width), ("height", height)],
                                     width: 200)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
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
        case NSEvent.SpecialKey.upArrow.rawValue:
            dy = jump
        case NSEvent.SpecialKey.downArrow.rawValue:
            newsize.height -= jump
            dy = -jump
        case NSEvent.SpecialKey.rightArrow.rawValue:
            dx = jump
        case NSEvent.SpecialKey.leftArrow.rawValue:
            newsize.width -= jump
            dx = -jump
        default:
            super.keyDown(with: theEvent)
        }
        size.width += dx
        size.height += dy
        changeSize(theNode, delta: size - theNode.size()!)
        // In the default case, the wall shortens at the right side, and the left side
        // is fixed. The option key reverses this.
        let factor: CGFloat = theEvent.modifierFlags.contains(.option) ? -1.0 : 1.0
        changePosition(theNode, delta: SCNVector3Make(factor * dx / 2.0, dy / 2.0, 0.0))
        let translation = SCNVector3Make(-dx / 2.0, -dy / 2.0, 0.0)
        for child in theNode.childNodes.filter({ nodeType($0) == .Picture }) {
            changePosition(child, delta: translation)
        }
        defaultWallSize.height = size.height
        let (_, _, width, height, _, _) = wallInfo(theNode)
        hudUpdate = makeDisplay(title: "Wall", items: [("width", width), ("height", height)], width: fontScaler * 210)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
        hideGrids()
    }
    
    func doBoxEditSize(_ theEvent: NSEvent)
    {
        guard let currentNode = theNode,
            let _ = currentNode.geometry as? SCNBox,
            let keyString = theEvent.charactersIgnoringModifiers?.utf16 else { return }
        let shift = checkModifierFlags(theEvent, flag: .shift, exclusive: false)
        let command = checkModifierFlags(theEvent, flag: .command, exclusive: false)
        let jump: CGFloat = shift ? 1 / 48.0 : 0.25 // ¼" or 3"
        let keyChar = Int(keyString[keyString.startIndex])
        var dWidth: CGFloat = 0.0
        var dLength: CGFloat = 0.0
        var dHeight: CGFloat = 0.0
        switch keyChar {
        case NSEvent.SpecialKey.upArrow.rawValue:
            if !command { dHeight = jump }
        case NSEvent.SpecialKey.downArrow.rawValue:
            if !command { dHeight -= jump }
        case NSEvent.SpecialKey.rightArrow.rawValue:
            if command {
                dLength = jump
            } else {
                dWidth = jump
            }
        case NSEvent.SpecialKey.leftArrow.rawValue:
            if command {
                dLength = -jump
            } else {
                dWidth = -jump
            }
        default:
            super.keyDown(with: theEvent)
        }
        let box = currentNode.geometry as! SCNBox
        box.width += dWidth
        box.length += dLength
        box.height += dHeight
		// The bottom of the box is on the floor.
		currentNode.position.y += dHeight / 2.0
		
        if nodeType(theNode) == .Table {
            fitTableToBox(theNode!)
        }
        let (_, _,  _, width, height, length, _) = boxInfo(currentNode)
        hudUpdate = makeDisplay(title: "Box", items: [("width", width), ("height", height), ("length", length)], width: fontScaler * 210)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
    }
    
    func doBoxEditPosition(_ theEvent: NSEvent) {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let currentNode = theNode else { return }
        let shift = theEvent.modifierFlags.contains(.shift)
		let option = theEvent.modifierFlags.contains(.option)
        let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0 // ¼" or 1"
		var dx: CGFloat = 0, dz: CGFloat = 0, dy: CGFloat = 0
        let keyChar = Int(keyString[keyString.startIndex])
        switch keyChar {
        case NSEvent.SpecialKey.rightArrow.rawValue:
            dx = jump
        case NSEvent.SpecialKey.leftArrow.rawValue:
            dx = -jump
        case NSEvent.SpecialKey.upArrow.rawValue:
			if option {
				dy = jump
			} else {
				dz = -jump
			}
        case NSEvent.SpecialKey.downArrow.rawValue:
			if option {
				dy = -jump
			} else {
				dz = jump
			}
        default:
            return
        }
        let translation = SCNVector3Make(dx, dy, dz)
        let d = Art_Scene.rotate(vector: translation, axis: SCNVector3Make(0, 1, 0), angle: artSceneView.camera().yRotation)
        currentNode.position = currentNode.position + d
        let (x, y, elevation, _, _, _, _) = boxInfo(currentNode)
        hudUpdate = makeDisplay(title: "Box",
                                items: [("↔", x), ("↕", y), ("↑", elevation)],
                                width: fontScaler * 150)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
    }
    
    
    /// Change the location and rotation of the camera with the arrow keys. The rotation
    /// is changed if the command key is down.
    func doCameraEdit(_ theEvent: NSEvent) {
        guard let keyString = theEvent.charactersIgnoringModifiers?.utf16 else { return }
        let charCode = Int(keyString[keyString.startIndex])
        let shift = checkModifierFlags(theEvent, flag: .shift, exclusive: false)
        let jump: CGFloat = shift ? 0.1 : 1.0
        let rotation: CGFloat = (shift ? 1.0 : 5.0) / r2d
        let cameraNode = artSceneView.camera()
        let omniLight = artSceneView.omniLight!
        SCNTransaction.animationDuration = 1.0
        let optionDown =  checkModifierFlags(theEvent, flag: .option, exclusive: false)
        let controlDown = checkModifierFlags(theEvent, flag: .control, exclusive: false)
        let commandDown =  checkModifierFlags(theEvent, flag: .command)
        if commandDown {
            var up: CGFloat = 0.0
            switch charCode {
            case NSEvent.SpecialKey.upArrow.rawValue:
                up += jump
            case NSEvent.SpecialKey.downArrow.rawValue:
                up -= jump
            default:
                super.keyDown(with: theEvent)
            }
            cameraNode.position.y += up
            omniLight.position = cameraNode.position
        } else if optionDown && controlDown {
            SCNTransaction.animationDuration = 2.0
            let quarter: CGFloat = .pi / 2.0
            var sign: CGFloat = 0
            switch charCode {
            case NSEvent.SpecialKey.leftArrow.rawValue:
                sign = 1
            case NSEvent.SpecialKey.rightArrow.rawValue:
                sign = -1
            default: return
            }
            let quadrant = Int(round(cameraNode.yRotation / quarter))
            let direction = (CGFloat(quadrant)  + sign) * quarter 
            cameraNode.yRotation = direction
        } else if optionDown {
            switch charCode {
            case NSEvent.SpecialKey.leftArrow.rawValue:
                cameraNode.yRotation += rotation
            case NSEvent.SpecialKey.rightArrow.rawValue:
                cameraNode.yRotation -= rotation
            case NSEvent.SpecialKey.upArrow.rawValue:
                cameraNode.eulerAngles.x += rotation
            case NSEvent.SpecialKey.downArrow.rawValue:
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
            case NSEvent.SpecialKey.upArrow.rawValue:
                v.x *= -1.0
                v.z *= -1.0
            case NSEvent.SpecialKey.leftArrow.rawValue:
                v = u
            case NSEvent.SpecialKey.rightArrow.rawValue:
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
        hideGrids()
    }
    
    func hideGrids(condition: CGFloat = 8.0)
    {
        let cameraNode = artSceneView.camera()
        let walls = artSceneView.nodesInsideFrustum(of: cameraNode).filter({ nodeType($0) == .Wall})
        for wall in walls {
            if let grid = wall.grid() {
               let position = wall.convertPosition(cameraNode.position, from: nil)
                let distance = position.z
               if distance <= condition * 2.0 {
                    grid.isHidden = false
                    grid.opacity = min(1.0, (condition * 2.0 - distance) / condition)
                } else {
                    grid.isHidden = true
                }
            }
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
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
        if undoer.groupingLevel == 1 {
            undoer.endUndoGrouping()
       }
        document!.undoManager!.undo()
    }
    
    /// Dispatch the key down event on `editMode`.
    override func keyDown(with theEvent: NSEvent)
    {
        SCNTransaction.animationDuration = 0.2
        let pad = theEvent.modifierFlags.contains(.numericPad)
        guard let keyString = theEvent.charactersIgnoringModifiers else { return }
        switch keyString {
        case "+":
            if #available(OSX 10.13, *)
            {
                camera.fieldOfView += 2.0
            } else {
                camera.xFov += 2.0
                camera.yFov += 2.0
            }
            updateCameraStatus()
            return
        case "-":
            if #available(OSX 10.13, *) {
                camera.fieldOfView -= 2.0
            }else {
                camera.xFov -= 2.0
                camera.yFov -= 2.0
            }
            updateCameraStatus()
            return
        case "i":
            artSceneView.getTheInfo(nil)
        case "c":
            let defaults = UserDefaults.standard
            cameraHidden = !cameraHidden
            defaults.set(cameraHidden, forKey: "cameraHidden")
        case "h":
            let defaults = UserDefaults.standard
            wantsCameraHelp = !wantsCameraHelp
            defaults.set(wantsCameraHelp, forKey: "wantsCameraHelp")
            artSceneView.isPlaying = true
       default:
            ()
        }
        if pad {
            if case EditMode.none = editMode {
                doCameraEdit(theEvent)
            } else {
                guard let theNode = theNode else {
                    status = "No object!"
                    return
                }
                if undoer.groupingLevel == 0 {
                    undoer.beginUndoGrouping()
                    undoer.setActionName(actionName(theNode, editMode)!)
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
                case .moving(.Box), .moving(.Chair), .moving(.Table):
                    doBoxEditPosition(theEvent)
                case .resizing(.Box, _):
                    doBoxEditSize(theEvent)
                case .resizing(.Table, _):
                    doBoxEditSize(theEvent)
                    fitTableToBox(theNode)
                default: ()
                }
            }
        }
        else {
            editMode = .none
        }
    }
}
