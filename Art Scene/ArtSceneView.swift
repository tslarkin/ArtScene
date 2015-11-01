//
//  GameView.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit

class ArtSceneView: SCNView {
    
    @IBOutlet weak var controller: ArtSceneViewController!
    weak var masterNode: SCNNode? = nil
    weak var mouseNode: SCNNode? = nil
    weak var mouseHit: SCNHitTestResult? = nil
    @IBOutlet weak var document: Document?
    var mouseClickLocation: SCNVector3? = nil
    
    var imageCacheForPrint: [String: NSImage]? = nil
    
    var wallColor: NSColor = NSColor.whiteColor() {
        didSet {
            if let walls = scene?.rootNode.childNodesPassingTest({ x, yes in x.name == "Wall" }) {
                for wall in walls {
                    wall.geometry?.firstMaterial?.diffuse.contents = wallColor
                }
            }
            
        }
    }
    
    var selection: Set<SCNNode>  = [] {
        didSet {
            if selection.count == 0 {
                masterNode = nil
            } else if selection.count == 1 {
                masterNode = Array(selection)[0]
            }
        }
    }
    
    override var scene: SCNScene? {
        didSet {
            NSThread.detachNewThreadSelector(Selector("makePrintImageCache"),
                toTarget: self, withObject: nil)
        }
    }
    
    var lastMousePosition: SCNVector3? = nil
    var lastYLocation: CGFloat = 0.0
    
    enum NodeEdge {
        case None
        case Top
        case Bottom
        case Left
        case Right
        case Pivot
    }
    
    enum EditMode {
        case None
        case MovingFrame
        case FrameWidth
        case FrameHeight
        case MovingWall
        case WallWidth
        case WallHeight
        case Selecting
        case ContextualMenu
        case GetInfo
        case RotateWall
        case Resizing(NodeEdge)
    }
    
    var editMode = EditMode.None
    var nodeEdge = NodeEdge.None
    var inDrag = false
    
    let questionCursor: NSCursor
    let rotateCursor: NSCursor
    
    required init?(coder: NSCoder) {
        var size: CGFloat = 24
        var image: NSImage = NSImage(size: NSSize(width: size, height: size))
        let font = NSFont.boldSystemFontOfSize(size)
        let q = "?"
        let attributes = [NSFontAttributeName: font, NSStrokeColorAttributeName: NSColor.whiteColor(),
            NSForegroundColorAttributeName: NSColor.blackColor(), NSStrokeWidthAttributeName: -2]
        image.lockFocus()
        q.drawInRect(NSRect(x: 0, y: 0, width: size, height: size), withAttributes:attributes)
        image.unlockFocus()
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 0, y: 0))
        
        size = 16
        let rotate = NSImage(named: "rotate-icon.png")!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        rotate.drawInRect(NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        rotateCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 0, y: 0))
        
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        registerForDraggedTypes([NSFilenamesPboardType])
        acceptsTouchEvents = true
    }
    
    func camera () -> SCNNode
    {
        return scene!.rootNode.childNodeWithName("Camera", recursively: false) as SCNNode!
    }
    
    func setPrintingCache(cache: [String: NSImage])
    {
        imageCacheForPrint = cache
    }
    
    func makePrintImageCache ()
    {
        var images: [String: NSImage] = [:]
        if let scene = scene {
            for picture in scene.rootNode.childNodesPassingTest ({ x, yes in x.name == "Picture" }) {
                if let (name, image) = makeThumbnail(picture) {
                    images[name] = image
                }
            }
            self.performSelectorOnMainThread(Selector("setPrintingCache:"), withObject: images, waitUntilDone: true)
        }
    }
    
    func getInfo(node: SCNNode) {
        var node = node
        if node.name == NodeType.Image.rawValue {
            node = node.parentNode!
        }
        if  let name = node.name,
            let type = NodeType(rawValue: name) {
                switch type {
                case .Wall:
                    let (size, location, rotation, distance) = wallInfo(node, camera: camera())
                    controller.status = "Wall Size: \(size); Position: \(location); Rotation: \(rotation); Distance: \(distance!)"
                case .Picture:
                    let (size, location, name) = pictureInfo(node)
                    if let name = name {
                        controller.status = "Picture Size: \(size); Position: \(location); Name: \(name)"
                    } else {
                        controller.status = "Picture Size: \(size); Position: \(location)"
                    }
                default:
                    break
                }
        }
    }
    
    override func keyDown(theEvent: NSEvent) {
        guard let s = theEvent.charactersIgnoringModifiers?.utf16 where
            theEvent.modifierFlags.contains(.CommandKeyMask)
            && Int(s[s.startIndex]) == NSDeleteCharacter
            else {
                super.keyDown(theEvent)
                return
        }
        if let undoer = undoManager {
            undoer.beginUndoGrouping()
            undoer.setActionName("Delete Pictures")
        }
        for picture in selection {
            picture.removeFromParentNode()
        }
        selection = []
        if let undoer = undoManager {
            undoer.endUndoGrouping()
        }
        document?.updateChangeCount(NSDocumentChangeType.ChangeDone)
    }
    
    override func mouseUp(theEvent: NSEvent) {
        inDrag = false
        if let child = mouseNode?.childNodeWithName("Wall", recursively: false) {
            child.removeFromParentNode()
        }
        if nodeType(mouseNode) == .Wall {
            if let material = mouseNode?.geometry?.firstMaterial {
                material.doubleSided = false
            }
        }
        mouseNode = nil
        if case .GetInfo = editMode {
            controller.status = ""
        }
//        editMode = .None
    }
    
    override func mouseMoved(theEvent: NSEvent) {
        if inDrag {
            return
        }
        
        switch editMode {
        case .GetInfo, .Selecting, .ContextualMenu:
            return
        default:
            break
        }

        editMode = .None
        mouseHit = nil
        mouseNode = nil
        let p = theEvent.locationInWindow
        lastYLocation = p.y
        if NSPointInRect(p, frame) {
            let hitResults = self.hitTest(p, options: [SCNHitTestFirstFoundOnlyKey: false, SCNHitTestSortResultsKey: true])
            if hitResults.count > 0 {
                if let wallHit = hitOfType(hitResults, type: .Wall) {
                    lastMousePosition = wallHit.localCoordinates
                }
                let hit = hitResults[0]
                mouseHit = hit
                mouseNode = hit.node
                if let type = nodeType(hit.node) {
                    switch type {
                    case .Left, .Right:
                        mouseNode = mouseNode?.parentNode?.parentNode
                        editMode = .FrameWidth
                        nodeEdge = type == .Left ? .Left : .Right
                        NSCursor.resizeLeftRightCursor().set()
                    case .Top, .Bottom:
                        mouseNode = mouseNode?.parentNode?.parentNode
                        editMode = .FrameHeight
                        nodeEdge = type == .Top ? .Top : .Bottom
                        NSCursor.resizeUpDownCursor().set()
                    case .Matt, .Image:
                        mouseNode = mouseNode?.parentNode
                        fallthrough
                    case .Picture:
                        editMode = .MovingFrame
                        nodeEdge = .None
                        NSCursor.openHandCursor().set()
                    case .Wall:
                        let local = NSPoint(x: hit.localCoordinates.x, y: hit.localCoordinates.y)
                        let node = hit.node
                        let size = nodeSize(node)
                        let width2 = size.width / 2
                        let height2 = size.height / 2
                        let cusp: CGFloat = 0.5
                        var rect = NSRect(x: -width2, y: -height2, width: cusp, height: size.height)
                        if NSPointInRect(local, rect) {
                            editMode = .WallWidth
                            nodeEdge = .Left
                            NSCursor.resizeLeftRightCursor().set()
                        } else {
                            rect = NSRect(x: width2 - cusp, y: -height2, width: cusp, height: size.height)
                            if NSPointInRect(local, rect) {
                                editMode = .WallWidth
                                nodeEdge = .Right
                                NSCursor.resizeLeftRightCursor().set()
                            } else {
                                rect = NSRect(x: -width2, y: height2 - cusp, width: size.width, height: cusp)
                                if NSPointInRect(local, rect) {
                                    editMode = .WallHeight
                                    nodeEdge = .Top
                                    NSCursor.resizeUpCursor().set()
                                } else {
                                    rect = NSRect(x: -width2, y: -height2, width: size.width, height: cusp)
                                    if NSPointInRect(local, rect) {
                                        editMode = .RotateWall
                                        nodeEdge = .None
                                        rotateCursor.set()
                                    } else {
                                        editMode = .MovingWall
                                        nodeEdge = .None
                                        NSCursor.openHandCursor().set()
                                    }
                                }
                            }
                        }
                    default:
                        NSCursor.arrowCursor().set()
                    }
                }
            } else {
                mouseNode = nil
                mouseHit = nil
                NSCursor.arrowCursor().set()
                super.mouseMoved(theEvent)
            }
        } else {
            NSCursor.arrowCursor().set()
            super.mouseMoved(theEvent)
        }
    }
    
    
    func showNodePosition(node: SCNNode) {
        let wall = node.parentNode
        let plane = wall?.geometry as! SCNPlane
        let x: CGFloat = node.position.x + plane.width / 2.0
        let y: CGFloat = node.position.y + plane.height / 2.0
        let xcoord = convertToFeetAndInches(x)
        let ycoord = convertToFeetAndInches(y)
        controller.status = "Picture Position: \(xcoord), \(ycoord)"
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        inDrag = true
        
        let p = theEvent.locationInWindow
        guard let mouseNode = mouseNode else { return }
        if case .RotateWall = editMode {
            let dy = p.y - lastYLocation
            lastYLocation = p.y
            mouseNode.eulerAngles.y += dy / 100
            let (_, _, rotation, _) = wallInfo(mouseNode)
            controller.status = "Wall Rotation: \(rotation)"
        }

        let hitResults = self.hitTest(p, options: nil)
        SCNTransaction.setAnimationDuration(0.0)
        guard let wallHit = hitOfType(hitResults, type: .Wall) else {
            return
        }
        
        let wall = wallHit.node
        let currentMousePosition = wallHit.localCoordinates
        let delta = CGPoint(x: currentMousePosition.x - lastMousePosition!.x,
            y: currentMousePosition.y - lastMousePosition!.y)
        switch editMode {
        case .MovingFrame:
            let dragged = selection.contains(mouseNode) ? selection : [mouseNode]
            for node in dragged {
                node.position.x += delta.x
                node.position.y += delta.y
                if wall !== node.parentNode {
                    node.removeFromParentNode()
                    wall.addChildNode(node)
                }
                if node === mouseNode {
                    showNodePosition(node)
                }
            }
        case .FrameHeight:
            if let geometry = mouseNode.geometry as? SCNPlane {
                let dy = nodeEdge == .Top ? delta.y : -delta.y
                var size = CGSize(width: geometry.width, height: geometry.height + dy)
                controller.reframePictureWithSize(mouseNode, size: &size)
                let (newsize, _, _) = pictureInfo(mouseNode)
                controller.status = "Picture Size: \(newsize)"
            }
        case .FrameWidth:
            if let geometry = mouseNode.geometry as? SCNPlane {
                let dx = nodeEdge == .Right ? delta.x : -delta.x
                var size = CGSize(width: geometry.width + dx, height: geometry.height)
                controller.reframePictureWithSize(mouseNode, size: &size)
                let (newsize, _, _) = pictureInfo(mouseNode)
                controller.status = "Picture Size: \(newsize)"
            }
            
        case .MovingWall:
            SCNTransaction.setAnimationDuration(0.2)
            let shift = theEvent.modifierFlags.contains(.ShiftKeyMask)
            let scale: CGFloat = shift ? 40.0 : 10.0
            let dx = theEvent.deltaX / scale
            let dy = theEvent.deltaY / scale
            moveNode(dy, deltaRight: -dx, node: mouseNode)
            let (_, location, _, distance) = wallInfo(wall, camera: camera())
            controller.status = "Wall Location: \(location); Camera distance: \(distance!)"
        case .WallWidth:
            if let geometry = mouseNode.geometry as? SCNPlane {
                let dx = nodeEdge == .Right ? delta.x : -delta.x
                let size = CGSize(width: geometry.width + dx, height: geometry.height)
                let newGeometry = SCNPlane(width: size.width, height: size.height)
                mouseNode.geometry = newGeometry
                let (newsize, _, _, _) = wallInfo(mouseNode)
                controller.status = "Wall Size: \(newsize)"
            }
        case .WallHeight:
            if let geometry = mouseNode.geometry as? SCNPlane {
                let dy = nodeEdge == .Top ? delta.y : -delta.y
                let size = CGSize(width: geometry.width, height: geometry.height + dy)
                let newGeometry = SCNPlane(width: size.width, height: size.height)
                mouseNode.geometry = newGeometry
                mouseNode.position.y += delta.y / 2
                let (newsize, _, _, _) = wallInfo(mouseNode)
                controller.status = "Wall Size: \(newsize)"
            }
        default:
            break
        }
        lastMousePosition = currentMousePosition
   }
    
    func setNodeEmission(parentNode: SCNNode, color: NSColor) {
        let children = parentNode.childNodesPassingTest {  x, yes in x.geometry != nil }

        for child in children {
            let material = child.geometry!.firstMaterial!
            material.emission.contents = color
        }
        
    }
        
    override func mouseDown(theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        controller.editMode = .Normal
        
        let p = theEvent.locationInWindow
        let hitResults = self.hitTest(p, options: nil)
        guard hitResults.count > 0 else { return }
        switch editMode {
        case .GetInfo:
            getInfo(hitResults[0].node)
        case .Selecting:
            guard let node = hitOfType(hitResults, type: .Picture)?.node
                else {
                    for node in selection {
                        setNodeEmission(node, color: NSColor.blackColor())
                    }
                    selection = []
                    break
            }
            let pictureNodes = Set([node])
            let selectedSet = Set<SCNNode>(selection)
            let hitSet = Set<SCNNode>(pictureNodes)
            let oldSelection = Set(selection)
            if theEvent.modifierFlags.contains(.CommandKeyMask) {
                selection = selectedSet.exclusiveOr(hitSet)
            } else {
                if selectedSet.intersect(hitSet).count == 0 {
                    selection = pictureNodes
                }
            }
            if selection.count == 1 {
                masterNode = Array(selection)[0]
                setNodeEmission(masterNode!, color: NSColor.redColor())
            } else {
                for node in Set(selection).intersect(pictureNodes) {
                    setNodeEmission(node, color: NSColor.blueColor())
                }
            }
            for node in oldSelection.subtract(selection) {
                setNodeEmission(node, color: NSColor.blackColor())
            }
        case .WallHeight, .WallWidth, .MovingWall, .RotateWall:
            if let wall = mouseNode where nodeType(mouseNode) == .Wall {
                let plane = controller.makeGlass(NSSize(width: 100, height: 100))
                let fakeWall = SCNNode(geometry: plane)
                fakeWall.name = "Wall"
                wall.addChildNode(fakeWall)
            }
        default:
            break
        }
    }

    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation {
        let hits = hitTest(sender.draggingLocation(), options: nil)
        guard let wallHit = hitOfType(hits, type: .Wall) else {
            controller.status = "No Wall Under Mouse"
            return NSDragOperation.None
        }
        let target = wallHit.localCoordinates
        let plane = wallHit.node.geometry as! SCNPlane
        let x = convertToFeetAndInches(target.x + plane.width / 2)
        let y = convertToFeetAndInches(target.y + plane.height / 2)
        controller.status = "Drop at \(x), \(y)"
        return NSDragOperation.Copy
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        if NSImage.canInitWithPasteboard(sender.draggingPasteboard()) {
            return NSDragOperation.Copy
        } else {
            return NSDragOperation.None
        }
    }
    
    override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
        return NSImage.canInitWithPasteboard(sender.draggingPasteboard())
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        var result = false
        let pasteboard = sender.draggingPasteboard()
        if let plist = pasteboard.propertyListForType(NSFilenamesPboardType) as! NSArray?
            where plist.count > 0 {
                let path = plist[0] as! String
                var point = sender.draggingLocation()
                point = convertPoint(point, fromView: nil)
                let hitResults = self.hitTest(point, options: nil)
                if hitResults.count > 0 {
                    if let pictureHit = hitOfType(hitResults, type: .Picture) {
                        result = true
                        controller.replacePicture(pictureHit.node, path: path)
                    } else if let wallHit = hitOfType(hitResults, type: .Wall) {
                        result = true
                        controller.addPicture(wallHit.node, path: path, point: wallHit.localCoordinates)
                    }
                
                }
        }
        
        return result
    }
    
    override func concludeDragOperation(sender: NSDraggingInfo?) {
        document?.updateChangeCount(NSDocumentChangeType.ChangeDone)

    }
}
