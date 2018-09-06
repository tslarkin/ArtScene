//
//  ArtSceneMouse.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/18/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit
import Cocoa

extension ArtSceneView
{
    
    func snapToGrid(d1: CGFloat, d2: CGFloat, snap: CGFloat)->(CGFloat, CGFloat) {
        if !snapToGridP {
            return (d1, d2)
        } else {
            var out1: CGFloat = 0.0
            var out2: CGFloat = 0.0
            deltaSum.x += d1
            deltaSum.y += d2
            let step = 1.0 / snap
            if abs(deltaSum.x) >= step {
                let times = Int(deltaSum.x * snap)
                out1 = CGFloat(times) / snap
                deltaSum.x -= out1
            }
            if abs(deltaSum.y) >= step {
                let times = Int(deltaSum.y * snap)
                out2 = CGFloat(times) / snap
                deltaSum.y -= out2
            }
            return (out1, out2)
        }
    }
    
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
                
        var hitResults: [SCNHitTestResult]
        if #available(OSX 10.13, *) {
            hitResults = hitTest(theEvent.locationInWindow, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
        } else {
            hitResults = hitTest(theEvent.locationInWindow, options: nil)
        }

        hitResults = hitResults.filter({ nodeType($0.node) != .Back && nodeType($0.node) != .Grid})
        hitResults = hitResults.filter({ nodeType($0.node) != .Picture || !theFrame($0.node).isHidden})
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
            if let pic = pictureOf(hit.node), theFrame(pic).isHidden {
                if nodeType(hit.node) != .Image {
                    mouseNode = pic.parent
                }
            } else {
                mouseNode = hit.node
            }
            return
        case .selecting:
            if let picture = pictureOf(hit.node) {
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
        
//        if let wallHit = hitOfType(hitResults, type: .Wall) {
//            lastMousePosition = wallHit.localCoordinates
//        }
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
                let optionDown = checkModifierFlags(theEvent, flag: .option)
                if optionDown {
                    editMode = .resizing(.Image, .none)
                    resizeCursor.set()
                    mouseNode = pictureOf(hit.node.parent!)
                } else {
                    fallthrough
                }
             case .Picture, .Matt:
                if case EditMode.getInfo = editMode {
                    mouseNode = hit.node
                } else {
                    mouseNode = pictureOf(hit.node)
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
            }
        }
    }
    
    /// Based on `editMode` and `mouseNode`, perform a drag operation, either resizing,
    /// moving, or rotating a wall.
    override func mouseDragged(with theEvent: NSEvent) {
        guard let mouseNode = mouseNode else {
            return
        }
        
        SCNTransaction.animationDuration = 0.1
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let scale: CGFloat = shift ? 80.0 : 20.0
        let dx = theEvent.deltaX / scale
        let dy = theEvent.deltaY / scale 
        let delta = CGPoint(x: dx, y: dy)
        
        var display: SKNode?
        
        // Switch on editMode
        switch editMode {
        case .moving(.Picture):
            let dragged = selection.contains(mouseNode) ? selection : [mouseNode]
            for node in dragged {
                let (dx, dy) = snapToGrid(d1: delta.x / 2.0, d2: -delta.y / 2.0, snap: gridFactor)
                if dx == 0.0 && dy == 0.0 { break }
                let translation = SCNVector3Make(dx, dy, 0.0)
                let hitResults: [SCNHitTestResult]
                if #available(OSX 10.13, *) {
                    hitResults = hitTest(theEvent.locationInWindow, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue as NSNumber])
                } else {
                    hitResults = hitTest(theEvent.locationInWindow, options: nil)
                }
                let wallHit = hitOfType(hitResults, type: .Wall)
                if let wall = wallHit?.node, wall != node.parent {
                    changeParent(node, from: node.parent, to: wall)
                    node.removeFromParentNode()
                    wall.addChildNode(node)
                    changePosition(node, from: node.position, to: wallHit!.localCoordinates)
                } else {
                    changePosition(node, delta: translation)
                }
                if node === mouseNode {
                    let (x, y, _, _, _, _) = pictureInfo2(mouseNode)
                    display = controller.makeDisplay(title: "Picture", items: [("↔", x), ("↕", y)], width: 150)
                }
            }
        case .resizing(.Picture, let edge):
            var size = mouseNode.size()!
            var dy: CGFloat = 0.0
            switch edge {
            case .top: dy = -delta.y
            case .bottom: dy = delta.y
            default: ()
            }
            var dx: CGFloat = 0.0
            switch edge {
            case .right: dx = delta.x
            case .left: dx = -delta.x
            default: ()
            }
            (dx, dy) = snapToGrid(d1: dx, d2: dy, snap: gridFactor)
            if dx == 0.0 && dy == 0.0 { break }
            size = CGSize(width: max(size.width + dx, 1.0 / 3.0), height: max(size.height + dy, 1.0 / 3.0)) // minimum size for picture is 4"
            controller.doChangePictureSize(mouseNode, from: mouseNode.size()!, to: size)
            let (_, _, width, height, _, _) = pictureInfo2(mouseNode)
            display = controller.makeDisplay(title: "Picture",
                                         items: [("width", width),
                                                 ("height", height)],
                                         width: 200)
        case .resizing(.Image, _):
            var size = theImage(mouseNode).size()!
            var dy = shift ? -delta.y / 4.0 : -delta.y
            if dy + size.height < minimumImageSize { break }
            var dx = dy * size.width / size.height
            (dx, dy) = snapToGrid(d1: dx, d2: dy, snap: gridFactor)
            if dx == 0.0 && dy == 0.0 { break }
            size = CGSize(width: size.width + dx, height: size.height + dy)
            controller.doChangeImageSize(mouseNode, from: theImage(mouseNode).size()!, to: size)
            let (width, height, name) = imageInfo2(mouseNode)
            display = controller.makeDisplay(title: name, items: [("width", width),
                                                              ("height", height)],
                                         width: 200)
        case .moving(.Wall):
            if !wallsLocked {
                SCNTransaction.animationDuration = 0.0
                let (dx, dz) = snapToGrid(d1: delta.x, d2: delta.y, snap: gridFactor)
                if dx == 0.0 && dz == 0.0 { break }
                let translation = SCNVector3Make(dx, 0.0, dz)
                changePosition(mouseNode, delta: translation)
                controller.hideGrids()
                let (x, z, _, _, _, dist) = wallInfo2(mouseNode, camera: camera())
                display = controller.makeDisplay(title: "Wall", items: [("↔", x), ("↕", z), ("↑", dist!)], width: 150)
            }
        case .resizing(.Wall, .pivot):
            var dy = delta.y / 2.0
            (dy, _) = snapToGrid(d1: dy, d2: 0.0, snap: rotationFactor)
            if (dy == 0) { return }
            let newAngle = mouseNode.eulerAngles.y + dy
            changePivot(mouseNode, from: mouseNode.yRotation, to: newAngle)
            controller.hideGrids(condition: 3.0)
            let (_, _, rotation, _) = wallInfo(mouseNode)
            controller.status = "Wall Rotation: \(rotation)"
            
            display = controller.makeDisplay(title: "Wall", items: [("y°", rotation)])
        case .resizing(.Wall, let edge):
            if !wallsLocked {
                let geometry = thePlane(mouseNode)
                SCNTransaction.animationDuration = 0.0
                var dy: CGFloat = 0.0
                var dx: CGFloat = 0.0
                var direction: CGFloat = 1.0
                switch edge {
                case .top: dy = -delta.y
                case .bottom: dy = delta.y
                case .right: dx = delta.x
                case .left: dx = -delta.x
                direction = -1.0
                default: ()
                }
                (dx, dy) = snapToGrid(d1: dx / 2.0, d2: dy / 2.0, snap: 2.0 * gridFactor)
                if dx == 0.0 && dy == 0.0 { break }
                let newSize = CGSize(width: geometry.width + dx, height: geometry.height + dy)
                // The wall must enclose all the pictures
                if newSize.width >= 0.5 && newSize.height >= 0.5
                    && wallContainsPictures(mouseNode, withNewSize: newSize)
                {
                    changeSize(mouseNode, from: mouseNode.size()!, to: newSize)
                    dx *= direction
                    var translation = SCNVector3Make(dx / 2.0, dy / 2.0, 0.0)
                    changePosition(mouseNode, delta: translation)
                    translation.x = -dx / 2.0
                    translation.y = -dy / 2.0
                    for child in mouseNode.childNodes.filter({ nodeType($0) == .Picture }) {
                        changePosition(child, delta: translation)
                    }
                    controller.hideGrids(condition: 3.0)
                    let (_, _, width, height, _, _) = wallInfo2(mouseNode)
                    display = controller.makeDisplay(title: "Wall",
                                                 items: [("width", width),
                                                        ("height", height)],
                                                 width: 200)
                }
            }
        default: ()
        }
        if display != nil {
            controller.hudUpdate = display
            display!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
        }
    }
    
    /// Switches according to `editMode`.
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        controller.editMode = .none
        deltaSum = CGPoint.zero
        if case EditMode.selecting = editMode,
            mouseNode == nil {
            for node in selection {
                setNodeEmission(node, color: NSColor.black)
            }
            selection = []
            return
        }
        let p = theEvent.locationInWindow
        var hitResults = hitTest(p, options: nil)
            //, options: [SCNHitTestOption.firstFoundOnly:  searchMode:  NSNumber(value: 1),
                                           //   SCNHitTestOption.ignoreHiddenNodes: NSNumber(value: true)])
        hitResults = hitResults.filter({ nodeType($0.node) != .Back && nodeType($0.node) != .Grid})
        guard hitResults.count > 0 else {
            return
        }
        if case EditMode.getInfo = editMode {
            mouseNode = hitResults[0].node
        }
        guard let mouseNode = mouseNode else { return }
        switch editMode {
        case .getInfo:
            if nodeType(mouseNode) == .Matt {
                getInfo(pictureOf(mouseNode)!, option: false, hitPosition: hitResults[0].worldCoordinates)
            } else {
                let option = checkModifierFlags(theEvent, flag: .option)
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
            let hitNode = Set([mouseNode])
            var selectionSet = Set(selection)
            let oldSelection = selectionSet
            // if mouse node is already in the selection, this removes it, otherwise adds it
            selectionSet = selectionSet.symmetricDifference(hitNode)
            if selectionSet.contains(mouseNode) {
                selection.append(mouseNode)
            } else {
                selection.remove(at: selection.index(of: mouseNode)!)
            }
           if selection.count > 0 {
                masterNode = selection.count == 0 ? mouseNode : selection[0]
                setNodeEmission(masterNode!, color: NSColor.red)
                for node in selectionSet.subtracting(Set([masterNode!])).intersection(hitNode) {
                    setNodeEmission(node, color: NSColor.blue)
                }
            }
            for node in oldSelection.subtracting(selectionSet) {
                setNodeEmission(node, color: NSColor.black)
            }
        case .resizing(.Wall, _):
            if !wallsLocked {
                prepareForUndo(mouseNode)
                inDrag = true
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
            undoer.endUndoGrouping()
        }
        
        inDrag = false
        mouseMoved(with: theEvent)
    }
    


}
