//
//  ArtSceneMouse.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/18/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit
import Cocoa

extension ArtSceneView
{
    /// Sets `mouseNode`, `editMode`, and the cursor image based on the the the first node in the
    /// sorted list of hits returned from `hitTest`.
    override func mouseMoved(with theEvent: NSEvent) {
        if inDrag { return }
        
        let p = theEvent.locationInWindow
        if !NSPointInRect(p, bounds) {
            NSCursor.arrow.set()
            super.mouseMoved(with: theEvent)
            return
        }
        
        switch editMode {
        case .getInfo:
            questionCursor.set()
        case .contextualMenu:
            NSCursor.contextualMenu.set()
        case .selecting:
            NSCursor.pointingHand.set()
        default:
            ()
        }


        // These modes are effected by changes to the keyboard flags, so are not affected by mouse movements
        switch editMode {
        case .selecting, .getInfo, .resizing(.Image, _), .contextualMenu: break
        default:
            NSCursor.arrow.set()
            mouseNode = nil
            editMode = .none
        }
        
        lastYLocation = p.y
        
        var hitResults = self.hitTest(p, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
        hitResults = hitResults.filter({ nodeType($0.node) != .Back})
        guard hitResults.count > 0  else /* no hits */ {
            if case EditMode.moving(_) = editMode {
                NSCursor.arrow.set()
            }
            super.mouseMoved(with: theEvent)
            return
        }
        let hit = hitResults[0]
        switch editMode {
        case .getInfo:
            if let pic = picture(hit.node), theFrame(pic).isHidden {
                if nodeType(hit.node) != .Image {
                    mouseNode = pic.parent
                }
            } else {
                mouseNode = hit.node
            }
            return
        case .selecting:
            if let picture = picture(hit.node) {
                mouseNode = picture
            } else {
                mouseNode = nil
            }
            return
        case .contextualMenu:
            mouseNode = hit.node
            return
        default:
            break
        }
        
        if let wallHit = hitOfType(hitResults, type: .Wall) {
            lastMousePosition = wallHit.localCoordinates
        }
        if let type = nodeType(hit.node) {
            switch type {
            case .Left, .Right:
                let edge: NodeEdge = type == .Left ? .left : .right
                editMode = .resizing(.Picture, edge)
                mouseNode = hit.node.parent!.parent!
                NSCursor.resizeLeftRight.set()
            case .Top, .Bottom:
                editMode = .resizing(.Picture, type == .Top ? .top : .bottom)
                mouseNode = hit.node.parent!.parent!
                NSCursor.resizeUpDown.set()
            case .Image:
                let theFlags = theEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let optionDown = theFlags.contains(.option) && theFlags.subtracting([.option]).isEmpty
                if optionDown {
                    editMode = .resizing(.Image, .none)
                    resizeCursor.set()
                    mouseNode = picture(hit.node.parent!)
                } else {
                    fallthrough
                }
             case .Picture, .Matt:
                if case EditMode.getInfo = editMode {
                    mouseNode = hit.node
                } else {
                    mouseNode = picture(hit.node)
                    editMode = .moving(.Picture)
                    NSCursor.openHand.set()
                }
            case .Wall:
                if wallsLocked {
                    mouseNode = hit.node
                    break
                }
                let local = NSPoint(x: hit.localCoordinates.x, y: hit.localCoordinates.y)
                mouseNode = hit.node
                let size = nodeSize(mouseNode!)
                let width2 = size.width / 2
                let height2 = size.height / 2
                let cusp: CGFloat = 0.5
                var rect = NSRect(x: -width2, y: -height2, width: cusp, height: size.height)
                if NSPointInRect(local, rect) {
                    editMode = .resizing(.Wall, .left)
                    NSCursor.resizeLeftRight.set()
                } else {
                    rect = NSRect(x: width2 - cusp, y: -height2, width: cusp, height: size.height)
                    if NSPointInRect(local, rect) {
                        editMode = .resizing(.Wall, .right)
                        NSCursor.resizeLeftRight.set()
                    } else {
                        rect = NSRect(x: -width2, y: height2 - cusp, width: size.width, height: cusp)
                        if NSPointInRect(local, rect) {
                            editMode = .resizing(.Wall, .top)
                            NSCursor.resizeUp.set()
                        } else {
                            rect = NSRect(x: -width2, y: -height2, width: size.width, height: cusp)
                            if NSPointInRect(local, rect) {
                                editMode = .resizing(.Wall, .pivot)
                                rotateCursor.set()
                            } else {
                                editMode = .moving(.Wall)
                                NSCursor.openHand.set()
                            }
                        }
                    }
                }
            default: ()
//                mouseNode = nil
//                editMode = .none
//                NSCursor.arrow.set()
            }
        }
//        if mouseNode == nil {
//            Swift.print("Lost the mouse node after mouse moved")
//        }
    }
    
    /// Based on `editMode` and `mouseNode`, perform a drag operation, either resizing,
    /// moving, or rotating a wall.
    override func mouseDragged(with theEvent: NSEvent) {
        guard let mouseNode = mouseNode else {
            return
        }
        let p = theEvent.locationInWindow
        
        // Handle the rotate operation separately, since there may not be a hit node, which is
        // not required to rotate.
        if case .resizing(.Wall, .pivot) = editMode {
            let dy = p.y - lastYLocation
            lastYLocation = p.y
            mouseNode.eulerAngles.y = mouseNode.eulerAngles.y + dy / 10
            let (_, _, rotation, _) = wallInfo(mouseNode)
            controller.status = "Wall Rotation: \(rotation)"
            return
        }
        
        // Find a hit node or bail.
        let hitResults = self.hitTest(p, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
        SCNTransaction.animationDuration = 0.0
        
        var wallHit = hitOfType(hitResults, type: .Wall)

        if mouseNode != wallHit?.node {
            switch editMode {
            case .resizing(.Wall, _), .moving(.Wall):
                let filter = hitResults.filter({$0.node === mouseNode})
                if filter.count > 0 {
                    wallHit = filter[0]
                } else {
                    wallHit = nil
                }
            default:
                ()
            }
        }
        
        let wall1: SCNNode?
        if wallHit == nil {
            if let fake = hitOfType(hitResults, type: .Fake) {
                wallHit = fake
                wall1 = fake.node.parent!
            } else {
                wall1 = nil
            }
        } else {
            wall1 = wallHit!.node
        }
        
        if wallHit == nil {
            return
        }
        
        guard let wall = wall1 else { return }
        
        let currentMousePosition = wallHit!.localCoordinates
        if lastMousePosition == nil {
            lastMousePosition = currentMousePosition
            return
        }
        // delta is the change in the mouse position.
        let delta = CGPoint(x: currentMousePosition.x - lastMousePosition!.x,
                            y: currentMousePosition.y - lastMousePosition!.y)
        
        // Switch on editMode
        switch editMode {
        case .moving(.Picture):
            let dragged = selection.contains(mouseNode) ? selection : [mouseNode]
            for node in dragged {
                node.position.x += delta.x
                node.position.y += delta.y
                // The drag may have gone from one wall to another
                if wall !== node.parent {
                    node.removeFromParentNode()
                    wall.addChildNode(node)
                    node.position = currentMousePosition
                }
                if node === mouseNode {
                    showNodePosition(node)
                }
            }
        case .resizing(.Picture, let edge):
            var size = mouseNode.size()!
            var dy: CGFloat = 0.0
            switch edge {
            case .top: dy = delta.y
            case .bottom: dy = -delta.y
            default: ()
            }
            var dx: CGFloat = 0.0
            switch edge {
            case .right: dx = delta.x
            case .left: dx = -delta.x
            default: ()
            }
            size = CGSize(width: size.width + dx, height: size.height + dy)
            controller.reframePictureWithSize(mouseNode, newsize: size)
            let (newsize, _, _, _) = pictureInfo(mouseNode)
            controller.status = "Picture Size: \(newsize)"
        case .resizing(.Image, _):
            var size = theImage(mouseNode).size()!
            let dy = delta.y / 2.0
            let dx = dy * size.width / size.height
            size = CGSize(width: size.width + dx, height: size.height + dy)
            controller.reframeImageWithSize(mouseNode, newsize: size)
            let (newsize, _) = imageInfo(mouseNode)
            controller.status = "Image size: \(newsize)"
        case .moving(.Wall):
            if wallsLocked {
                break
            }
            SCNTransaction.animationDuration = 0.2
            let shift = theEvent.modifierFlags.contains(.shift)
            let scale: CGFloat = shift ? 80.0 : 20.0
            let size = CGSize(width: theEvent.deltaX / scale, height: theEvent.deltaY / scale)
            moveNode(size.height, deltaRight: -size.width, node: mouseNode, angle: camera().eulerAngles.y)
            let (_, location, _, distance) = wallInfo(wall, camera: camera())
            controller.status = "Wall Location: \(location); \(distance!) feet away"
        case .resizing(.Wall, let edge):
            if !wallsLocked {
                let geometry = thePlane(mouseNode)
                SCNTransaction.animationDuration = 0.0
                var factor: Float = 1.0
                var dy: CGFloat = 0.0
                var dx: CGFloat = 0.0
                switch edge {
                case .top: dy = delta.y
                case .bottom: dy = -delta.y
                case .right: dx = delta.x
                case .left:
                    factor = -1.0
                    dx = -delta.x
                default: ()
                }
                let newSize = CGSize(width: geometry.width + dx, height: geometry.height + dy)
                // The wall must enclose all the pictures
                if newSize.width >= 0.5 && newSize.height >= 0.5
                    && wallContainsPictures(mouseNode, withNewSize: newSize)
                {
                    mouseNode.setSize(newSize)
//                    mouseNode.pivot = SCNMatrix4Translate(mouseNode.pivot, -dx / 2.0, 0.0, -dy)
                    let translate = simd_make_float3(factor * Float(dx / 2.0), factor * Float(dy / 2.0), 0.0)
                    mouseNode.simdLocalTranslate(by: translate)
                    for child in mouseNode.childNodes.filter({ nodeType($0) == .Picture }) {
                        child.position.y -= dy / 2
                        child.position.x -= dx / 2.0
                    }
                    let (newsize, _, _, _) = wallInfo(mouseNode)
                    controller.status = "Wall Size: \(newsize)"
                }
            }
        default: ()
        }
        lastMousePosition = currentMousePosition
    }
    
    /// Switches according to `editMode`.
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        controller.editMode = .none
        if case EditMode.selecting = editMode,
            mouseNode == nil {
            for node in selection {
                setNodeEmission(node, color: NSColor.black)
            }
            selection = []
            return
        }
        let p = theEvent.locationInWindow
        let hitResults = self.hitTest(p, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
        guard hitResults.count > 0 else {
            return
        }
        if nodeType(hitResults[0].node) == .Back {
            return
        }
        if case EditMode.getInfo = editMode {
            mouseNode = hitResults[0].node
        }
        guard let mouseNode = mouseNode else { return }
        switch editMode {
        case .getInfo:
            if nodeType(mouseNode) == .Matt {
                getInfo(picture(mouseNode)!)
            } else {
                let option = theEvent.modifierFlags.contains(.option)
                getInfo(mouseNode, option: option, hitPosition: hitResults[0].worldCoordinates)
            }
        case .moving(.Wall):
            if !wallsLocked {
                prepareForUndo(mouseNode)
                inDrag = true
                NSCursor.closedHand.set()
            }
        case .moving(.Picture):
            prepareForUndo(mouseNode)
            inDrag = true
            NSCursor.closedHand.set()
        case .selecting:
            let pictureNodes = Set([mouseNode])
            let selectedSet = Set<SCNNode>(selection)
            let hitSet = Set<SCNNode>(pictureNodes)
            let oldSelection = Set(selection)
            if theEvent.modifierFlags.contains(.command) {
                selection = selectedSet.symmetricDifference(hitSet)
            } else {
                if selectedSet.intersection(hitSet).count == 0 {
                    selection = pictureNodes
                }
            }
            if selection.count == 1 {
                masterNode = Array(selection)[0]
                setNodeEmission(masterNode!, color: NSColor.red)
            } else {
                for node in Set(selection).intersection(pictureNodes) {
                    setNodeEmission(node, color: NSColor.blue)
                }
            }
            for node in oldSelection.subtracting(selection) {
                setNodeEmission(node, color: NSColor.black)
            }
        case .resizing(.Wall, _):
            if !wallsLocked {
                // Make a gigantic transparent wall coplanar with `mouseNode` so that the mouse can be off
                // the wall while dragging it larger.
                prepareForUndo(mouseNode)
                inDrag = true
                let fakeWall = controller.makeFakeWall()
                mouseNode.addChildNode(fakeWall)
            }
        case .resizing(.Picture, _):
            prepareForUndo(mouseNode)
            inDrag = true
        case .resizing(.Image, _):
            prepareForUndo(mouseNode)
            inDrag = true
        default: ()
//            editMode = .none
        }
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        if inDrag == true {
            guard let mouseNode = mouseNode else { return }
            undoer.setActionName(actionName(mouseNode, editMode)!)
            switch editMode {
            case .resizing(.Picture, _):
                let size = snapToGrid(mouseNode.size()!)
                controller.doChangePictureSize(mouseNode, from: saved as! CGSize, to: size)
                let (newsize, _, _, _) = pictureInfo(mouseNode)
                controller.status = "Picture Size: \(newsize)"
            case .resizing(.Image, _):
                let size = theImage(mouseNode).size()!
                controller.doChangeImageSize(mouseNode, from: saved as! CGSize, to: size)
                let (newsize, _) = imageInfo(mouseNode)
                controller.status = "Image size: \(newsize)"
                editMode = .none
                NSCursor.arrow.set()
            case .resizing(.Wall, let edge):
                if wallsLocked {
                    break
                }
                let (oldSize, oldPosition, oldChildPositions) = saved as! (CGSize, SCNVector3, [SCNVector3])
                let currentSize = mouseNode.size()!
                let newSize = snapToGrid(mouseNode.size()!)
                undoer.beginUndoGrouping()
                changeSize(mouseNode, from: oldSize, to: newSize)
                let delta = CGSize(width: newSize.width - currentSize.width,
                                   height: newSize.height - currentSize.height)
                let translate = simd_make_float3(Float(delta.width / 2.0),
                                                 Float(delta.height / 2.0),
                                                 0.0)
                mouseNode.simdLocalTranslate(by: translate)
                changePosition(mouseNode, from: oldPosition, to: mouseNode.position)
                let childen = mouseNode.childNodes.filter({ nodeType($0) == .Picture })
                let zipped = zip(childen, oldChildPositions)
                for (child, oldPosition) in zipped {
                    let factor: CGFloat = edge == .right ? 1.0 : -1.0
                    var position = child.position
                    position.y -= delta.height / 2.0
                    position.x += factor * delta.width / 2.0
                    changePosition(child, from: oldPosition, to: position)
                }
                undoer.endUndoGrouping()
                let (newsize, _, _, _) = wallInfo(mouseNode)
                controller.status = "Wall Size: \(newsize)"
            case .moving(.Picture):
                undoer.beginUndoGrouping()
                for (node, oldPosition, parent) in saved as! [(SCNNode, SCNVector3, SCNNode)] {
                    let position = snapToGrid(node.position)
                    changePosition(node, from: oldPosition, to: position)
                    changeParent(node, from: parent, to: node.parent!)
                }
                undoer.endUndoGrouping()
                showNodePosition(mouseNode)
            case .moving(.Wall):
                if !wallsLocked {
                    let position = snapToGrid(mouseNode.position)
                    changePosition(mouseNode, from: saved as! SCNVector3, to: position)
                }
            default: ()
            }
        }
        
        inDrag = false
        // Remove the false wall.
        if let child = mouseNode?.childNode(withName: "Fake", recursively: false) {
            child.removeFromParentNode()
        }
//        if !(case .selecting = editMode) {
//            mouseNode = nil
//        }
//        flagsChanged(with: theEvent)
    }
    


}
