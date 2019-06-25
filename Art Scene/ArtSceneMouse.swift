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
//            NSCursor.arrow.set()
//            super.mouseMoved(with: theEvent)
            return
        }

        switch editMode {
        case .getInfo:
            questionCursor.set()
        case .contextualMenu:
            if !checkModifierFlags(theEvent, flag: .control) {
                editMode = .none
            } else {
                NSCursor.contextualMenu.set()
            }
        case .selecting:
            NSCursor.pointingHand.set()
        default:
            ()
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
            if !(editMode == EditMode.getInfo) && !(editMode == .none) {
                NSCursor.arrow.set()
                selectedNode = nil
                editMode = .none
            }
            return
        }
        let hit = hitResults[0]
        switch editMode {
        case .getInfo:
            selectedNode = hit.node
            return
        case .selecting:
            if let picture = pictureOf(hit.node) {
                selectedNode = picture
            } else {
                selectedNode = nil
            }
            return
        case .contextualMenu:
            selectedNode = hit.node
            return
        default:
            break
        }
        
        guard let type = nodeType(hit.node) else {
            NSCursor.arrow.set()
            selectedNode = nil
            editMode = .none
            return
        }
        switch type {
        case .Chair:
            selectedNode = hit.node
            if hit.worldCoordinates.y < 0.25 {
                rotateCursor.set()
                editMode = .rotating(.Chair)
            } else {
                editMode = .moving(.Chair)
                NSCursor.openHand.set()
            }
        case .Box, .Table:
            selectedNode = hit.node
			let box = hit.node.geometry as! SCNBox
			let bottom = -box.height / 2.0
            if hit.localCoordinates.y >= bottom && hit.localCoordinates.y <= (bottom + 0.25) {
                rotateCursor.set()
                editMode = .rotating(type)
            } else {
                // 0 and 2 are the width dimension.
                let loc = hit.localCoordinates
                let cusp: CGFloat = box.height / 6.0
                if loc.y > box.height / 2.0 - cusp {
                        editMode = .resizing(type, .side(4, .top))
                        NSCursor.resizeUpDown.set()
                    return
                }
                switch hit.geometryIndex {
                case 0, 2:
                    let cusp1 = box.width / 2.0
                    var inside = CGRect(x: 0, y: 0, width: box.width - cusp1, height: box.height - cusp)
                    inside = NSOffsetRect(inside, -(box.width - cusp1) / 2.0, -(box.height - cusp) / 2.0)
                    if NSPointInRect(NSPoint(x: loc.x, y: loc.y), inside) {
                        editMode = .moving(type)
                        NSCursor.openHand.set()
                    } else  {
                        if hit.geometryIndex == 0 {
                            if loc.x > 0 {
                                editMode = .resizing(type, .side(hit.geometryIndex, .right))
                                NSCursor.resizeRight.set()
                            } else {
                                editMode = .resizing(type, .side(hit.geometryIndex, .left))
                                NSCursor.resizeLeft.set()
                            }
                        } else if loc.x < 0 {
                            editMode = .resizing(type, .side(hit.geometryIndex, .right))
                            NSCursor.resizeRight.set()
                        } else {
                            editMode = .resizing(type, .side(hit.geometryIndex, .left))
                            NSCursor.resizeLeft.set()
                        }

                    }
                case 1, 3:
                    let cusp1 = box.length / 2.0
                    var inside = CGRect(x: 0, y: 0, width: box.length - cusp1, height: box.height - cusp)
                    inside = NSOffsetRect(inside, -(box.length - cusp1) / 2.0, -(box.height - cusp) / 2.0)
                    if NSPointInRect(NSPoint(x: loc.z, y: loc.y), inside) {
                        editMode = .moving(type)
                        NSCursor.openHand.set()
                    } else if type != .Chair {
                        if hit.geometryIndex == 1 {
                            if loc.z > 0 {
                                editMode = .resizing(type, .side(hit.geometryIndex, .left))
                                NSCursor.resizeLeft.set()
                            } else {
                                editMode = .resizing(type, .side(hit.geometryIndex, .right))
                                NSCursor.resizeRight.set()
                            }
                        } else if loc.z < 0 {
                            editMode = .resizing(type, .side(hit.geometryIndex, .left))
                            NSCursor.resizeLeft.set()
                        } else {
                            editMode = .resizing(type, .side(hit.geometryIndex, .right))
                            NSCursor.resizeRight.set()
                        }
                    }
                case 4:
                    editMode = .moving(type)
                    NSCursor.openHand.set()
                default: ()
                }
            }
        case .Left, .Right:
            let edge: NodeEdge = type == .Left ? .left : .right
            editMode = .resizing(.Picture, edge)
            selectedNode = hit.node.parent!.parent!
            NSCursor.resizeLeftRight.set()
        case .Top, .Bottom:
            editMode = .resizing(.Picture, type == .Top ? .top : .bottom)
            selectedNode = hit.node.parent!.parent!
            NSCursor.resizeUpDown.set()
        case .Image:
            let optionDown = checkModifierFlags(theEvent, flag: .option)
            if optionDown {
                editMode = .resizing(.Image, .none)
                resizeCursor.set()
                selectedNode = pictureOf(hit.node.parent!)
            } else {
                fallthrough
            }
        case .Picture, .Matt:
            if case EditMode.getInfo = editMode {
                selectedNode = hit.node
            } else {
                selectedNode = pictureOf(hit.node)
                editMode = .moving(.Picture)
                NSCursor.openHand.set()
            }
        case .Wall:
            if wallsLocked {
                selectedNode = hit.node
                if case EditMode.getInfo = editMode {
                } else {
                    NSCursor.arrow.set()
                    editMode = .none
                }
                break
            }
            let local = NSPoint(x: hit.localCoordinates.x, y: hit.localCoordinates.y)
            selectedNode = hit.node
            let size = nodeSize(selectedNode!)
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
                            editMode = .rotating(.Wall)
                            rotateCursor.set()
                        } else {
                            editMode = .moving(.Wall)
                            NSCursor.openHand.set()
                        }
                    }
                }
            }
        default:
            NSCursor.arrow.set()
            selectedNode = nil
            editMode = .none
        }
        if selectedNode === scene?.rootNode {
            Swift.print("Yoiks!")
        }
        
    }
    
    /// Based on `editMode` and `mouseNode`, perform a drag operation, either resizing,
    /// moving, or rotating a wall, picture, selection of pictures, or furniture.
    override func mouseDragged(with theEvent: NSEvent) {
        guard let currentNode = selectedNode else {
            return
        }
        
        SCNTransaction.animationDuration = 0.0
        let shift = checkModifierFlags(theEvent, flag: .shift)
        let scale: CGFloat = shift ? 80.0 : 20.0
        let dx = theEvent.deltaX / scale
        let dy = theEvent.deltaY / scale 
        let delta = CGPoint(x: dx, y: dy)
        
        var display: SKNode?
        
        // Switch on editMode
        switch editMode {
        // Drag a picture or selection of pictures.
        case .moving(.Picture):
            let dragged = selection.contains(currentNode) ? selection : [currentNode]
            for node in dragged {
                // Determine the translation
                let (dx, dy) = snapToGrid(d1: delta.x / 2.0, d2: -delta.y / 2.0, snap: gridFactor)
                if dx == 0.0 && dy == 0.0 { break }
                let translation = SCNVector3Make(dx, dy, 0.0)
                // Did the drag move to another wall? If so, then the picture moves to the new wall.
                let hitResults: [SCNHitTestResult]
                if #available(OSX 10.13, *) {
                    hitResults = hitTest(theEvent.locationInWindow, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue as NSNumber])
                } else {
                    hitResults = hitTest(theEvent.locationInWindow, options: nil)
                }
                let wallHit = hitOfType(hitResults, type: .Wall)
                if let wall = wallHit?.node, wall != node.parent {
                    changeParent(node, to: wall)
                    node.removeFromParentNode()
                    wall.addChildNode(node)
                    changePosition(node, delta: wallHit!.localCoordinates - node.position)
                } else {
                    changePosition(node, delta: translation)
                }
                // The status display reports the location of the dragged picture.
                if node === currentNode {
                    let (x, y, _, _, _, _) = pictureInfo(currentNode)
                    display = makeDisplay(title: "Picture", items: [("↔", x), ("↕", y)], width: fontScaler * 150)
                }
            }
        // Resizing the picture (frame and mat)
        case .resizing(.Picture, let edge):
            // Figure the size delta
            var size = currentNode.size()!
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
            // Constrain the minimum size of a picture.
            size = CGSize(width: max(size.width + dx, 1.0 / 3.0), height: max(size.height + dy, 1.0 / 3.0)) // minimum size for picture is 4"
            doChangePictureSize(currentNode, to: size)
            let (_, _, width, height, _, _) = pictureInfo(currentNode)
            display = makeDisplay(title: "Picture", items: [("width", width), ("height", height)], width: fontScaler * 200)
        // Resize the image. The frame and mat resize proportionally.
        case .resizing(.Image, _):
            var size = theImage(currentNode).size()!
            var dy = shift ? -delta.y / 4.0 : -delta.y
            if dy + size.height < minimumImageSize { break }
            var dx = dy * size.width / size.height
            (dx, dy) = snapToGrid(d1: dx, d2: dy, snap: gridFactor)
            if dx == 0.0 && dy == 0.0 { break }
            size = CGSize(width: size.width + dx, height: size.height + dy)
            doChangeImageSize(currentNode, from: theImage(currentNode).size()!, to: size)
            let (width, height, name) = imageInfo(currentNode)
            display = makeDisplay(title: name, items: [("width", width), ("height", height)], width: fontScaler * 200)
        // Move a wall. This is very simple. The pictures don't need to be moved because their positions are
        // in the wall's coordinate system.
        case .moving(.Wall):
            if !wallsLocked {
                SCNTransaction.animationDuration = 0.0
                let (dx, dz) = snapToGrid(d1: delta.x, d2: delta.y, snap: gridFactor)
                if dx == 0.0 && dz == 0.0 { break }
                let translation = SCNVector3Make(dx, 0.0, dz)
                changePosition(currentNode, delta: translation, povAngle: camera.yRotation)
                hideGrids()
                let (x, z, _, _, _, dist) = wallInfo(currentNode, camera: camera)
                display = makeDisplay(title: "Wall", items: [("↔", x), ("↕", z), ("↑", dist!)], width: fontScaler * 150)
            }
        // Rotate the wall.
        case .rotating(.Wall):
            var dy = delta.x / 6.0
            (dy, _) = snapToGrid(d1: dy, d2: 0.0, snap: rotationFactor)
            if (dy == 0) { return }
            let newAngle = currentNode.eulerAngles.y + dy
            // The name changePivot is unfortunate since the pivot has another meaning in Scene Kit.
            changePivot(currentNode, delta: newAngle - currentNode.yRotation)
            hideGrids()
            let (_, _, _, _, rotation, _) = wallInfo(currentNode)
            display = makeDisplay(title: "Wall", items: [("y°", rotation)])
        // Resize the wall. This is a bit more complicated because we want the pictures to maintain
        // their positions as the wall resizes. What this means currently is that the pictures move
        // half the distance of the wall size change, but in the opposite direction.
        // Again, the edge of the wall opposite the active edge doesn't move, so the wall has to
        // move to compensate for the fact that the wall naturally resizes symmetrically from the center.
        // This case handles changes to both the height and the width of the walls. (Walls have no length, aka depth,
        // since they are two dimensional.
        case .resizing(.Wall, let edge):
            if !wallsLocked {
                // Compute the dx and dy. Actually, only one of these will change, depending on which edge
                // is active.
                let geometry = thePlane(currentNode)
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
                // Constrain the minimum size of a wall.
                if newSize.width >= 0.5 && newSize.height >= 0.5
                {
                    changeSize(currentNode, delta: newSize - currentNode.size()!)
                    dx *= direction
                    var translation = SCNVector3Make(dx / 2.0, dy / 2.0, 0.0)
                    
                    // change the position so that the other side of the wall stays fixed.
                    changePosition(currentNode, delta: translation, povAngle: camera.yRotation)
                    // Change the position of the pictures so that they stay the same distance
                    // from the inactive edge.
                    translation.x = -dx / 2.0
                    translation.y = -dy / 2.0
                    for child in currentNode.childNodes.filter({ nodeType($0) == .Picture }) {
                        changePosition(child, delta: translation)
                    }
                    hideGrids()
                    let (_, _, width, height, _, _) = wallInfo(currentNode)
                    display = makeDisplay(title: "Wall",
                                                     items: [("width", width),
                                                             ("height", height)],
                                                     width: 200)
                }
            }
        // Moving floor objects. They all move the same way.
        case .moving(.Box), .moving(.Chair), .moving(.Table):
            SCNTransaction.animationDuration = 0.0
            var (dx, dz) = snapToGrid(d1: delta.x, d2: delta.y, snap: gridFactor)
            if dx == 0.0 && dz == 0.0 { break }
			var dy: CGFloat = 0.0
			if theEvent.modifierFlags.contains(.option) && nodeType(currentNode) == .Box {
				dy = -dz
				dz = 0
			}
            let translation = SCNVector3Make(dx, dy, dz)
            // Rotate the translation so that the vector is rotated relative the camera. It turns out that the
            // user expects that when she drags left (or right) the object moves relative to her, not relative
            // to the object's coordinate system.
            let d = Art_Scene.rotate(vector: translation, axis: SCNVector3Make(0, 1, 0), angle: camera.yRotation)
            currentNode.position = currentNode.position + d
            let (x, y, elevation, _, _, _, _) = boxInfo(currentNode)
            display = makeDisplay(title: "\(String(describing: currentNode.name!))", items: [("↔", x), ("↕", y), ("↑", elevation)], width: fontScaler * 150)
        // Rotating of all furniture is the same.
        case .rotating(.Box), .rotating(.Chair), .rotating(.Table):
            if delta.x == 0.0 { return }
            currentNode.yRotation += delta.x / 4.0
            let (_, _, _, _, _, _, rotation) = boxInfo(currentNode)
            display = makeDisplay(title: "\(String(describing: currentNode.name!))", items: [("y°", rotation)], width: fontScaler * 150)
        // Change any of the dimensions of the box.
        // If the top (face = 4), the change the box height, and move the box up to keep it on the floor.
        // This case also handles changing the length (z-axis) and width (x-axis) of the box.
        // There are four cases to consider. We can be changing the x size or the z size,
        // and the change can be made on the left side or right side of the face, which
        // is determined by which edge has been identified by mouseMoved as the edge the
        // mouse is currently over. The other size doesn't move. Since the box changes size
        // symmetrically with respect to the center, the box has to move to keep the other
        // edge from moving.
        case .resizing(let type, .side(let face, let edge)):
            SCNTransaction.animationDuration = 0.0
            var dWidth: CGFloat = 0.0
            var dLength: CGFloat = 0.0
            var dHeight: CGFloat = 0.0
            var sign: CGFloat = NodeEdge.left == edge ? -1.0 : 1.0
            switch face {
            case 0, 2:
                dWidth = sign * delta.x / 2.0
                if face == 0 {
                    sign *= -1.0
                }
            case 1, 3:
                dLength = sign * delta.x / 2.0
                if face == 3 {
                    sign *= -1.0
                }
            case 4:
                dHeight = -delta.y / 2.0
            default: ()
            }
            if dWidth == 0.0 && dLength == 0 && dHeight == 0.0 { break }
            let box = currentNode.geometry as! SCNBox
            box.width += dWidth
            box.length += dLength
            box.height += dHeight
            let delta = SCNVector3Make(dWidth * sign, -dHeight, dLength * sign)
            // Again, rotate the movement vector so that the movement happens with respect to the
            // coordinate system of the camera.
            let d = Art_Scene.rotate(vector: delta, axis: SCNVector3Make(0, 1, 0), angle: currentNode.yRotation)
            currentNode.position = currentNode.position - 0.5 * d
 			// Resize the table. The size of the table top does not increase; the height of the legs increase.
           if type == .Table {
                fitTableToBox(currentNode)
            }
            let (_, _, _, width, height, length, _) = boxInfo(currentNode)
            display = makeDisplay(title: "\(String(describing: currentNode.name!))",
                items: [("width", width), ("length", length), ("height", height)], width: fontScaler * 200)
        default: ()
        }
        if display != nil {
            hudUpdate = display
            display!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
        }
    }
    
    /// Switches according to `editMode`.
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        deltaSum = CGPoint.zero
        if case EditMode.selecting = editMode,
            selectedNode == nil {
            for node in selection {
                setNodeEmission(node, color: NSColor.black)
            }
            selection = []
            return
        }
        
        guard let mouseNode = selectedNode else { return }
        switch editMode {
        case .getInfo:
            var hitResults: [SCNHitTestResult]
            if #available(OSX 10.13, *) {
                hitResults = hitTest(theEvent.locationInWindow, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
            } else {
                hitResults = hitTest(theEvent.locationInWindow, options: nil)
            }
            hitResults = hitResults.filter({ nodeType($0.node) != .Back && nodeType($0.node) != .Grid})
            hitResults = hitResults.filter({ nodeType($0.node) != .Picture || !theFrame($0.node).isHidden})
            guard hitResults.count > 0 else {
                return
            }
            if nodeType(mouseNode) == .Wall {
                getInfo(mouseNode, option: false, hitPosition: hitResults[0].worldCoordinates)
            } else if nodeType(mouseNode) == .Matt {
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
            let wall = mouseNode.parent!
            for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid && $0.name != nil}) {
                flattenPicture(node)
            }
            fallthrough
        case .moving(_):
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
                selection.remove(at: selection.firstIndex(of: mouseNode)!)
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
        case .rotating(_):
            prepareForUndo(mouseNode)
            inDrag = true
        case .resizing(.Wall, _):
            if !wallsLocked {
                prepareForUndo(mouseNode)
                inDrag = true
            }
        case .resizing(_, _):
            prepareForUndo(mouseNode)
            inDrag = true
        default: ()
        }
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        if inDrag == true {
            undoer.endUndoGrouping()
            if editMode == .moving(.Picture) {
                let wall = selectedNode!.parent!
                for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid  && $0.name != nil}) {
                    unflattenPicture(node)
                }
            }
        }
        
        inDrag = false
        mouseMoved(with: theEvent)
    }
    


}
