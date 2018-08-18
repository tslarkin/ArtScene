//
//  GameView.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit

/**
Hosts the Art Scene. It also handles mouse events (including keeping track of the selection),
and printing.
*/
class ArtSceneView: SCNView, Undo {

    /// A reference to its controller
    @IBOutlet weak var controller: ArtSceneViewController!
    /// The alignment functions use a master node as a reference.
    weak var masterNode: SCNNode? = nil
    /// The node under the mouse, set during `mouseMoved`.
    weak var mouseNode: SCNNode? = nil
//    weak var mouseHit: SCNHitTestResult? = nil
    /// The Art Scene document
    @IBOutlet weak var document: Document?
    /// The location of the last mouse click that generated a contextual menu.
    var mouseClickLocation: SCNVector3? = nil
    /// The documents undo manager
    var undoer:UndoManager {
        get { return (document?.undoManager)! }
    }
    
    /// A cache for NSImages for each of the pictures. Used only for printing.
    var imageCacheForPrint: [String: NSImage]? = nil
    
    /// The user selected wall color, which is the same for all walls
    var wallColor: NSColor = NSColor.white {
        didSet {
            if let walls = scene?.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall" }) {
                for wall in walls {
                    wall.geometry?.firstMaterial?.diffuse.contents = wallColor
                }
            }
            
        }
    }
    
    /// The set of selected pictures. The first picture selected is always the `masterNode`.
    var selection: Set<SCNNode>  = [] {
        didSet {
            if selection.count == 0 {
                masterNode = nil
            } else if selection.count == 1 {
                masterNode = Array(selection)[0]
            }
        }
    }
    
    /// Detach a thread to make the image cache.
    override var scene: SCNScene? {
        didSet {
            Thread.detachNewThreadSelector(#selector(makePrintImageCache),
                toTarget: self, with: nil)
        }
    }
    
    /// The last mouse position as determined during `mouseMoved`.
    var lastMousePosition: SCNVector3? = nil
    /// Used while dragging to rotate a wall. The mouse y coordinate is used since
    /// the mouse may not be over a wall or picture during the drag.
    var lastYLocation: CGFloat = 0.0
    
    /// Set during `mouseMoved` based on which node the mouse is over, as determined by
    /// `hitTest`.
    var editMode = EditMode.none
    
    /// Indicates whether the user is currently in a drag operation.
    var inDrag = false
    
    /// The cursor for Get Info.
    let questionCursor: NSCursor
    /// The cursor that appears when the mouse is over the bottom of a wall.
    let rotateCursor: NSCursor
    /// The resize uniformly cursor.
    let resizeCursor: NSCursor
    
    var wallsLocked: Bool {
        return controller.wallsLocked
    }
    
    var saved: Any = ""
    
    /// Makes the `questionCursor` and `rotateCursor`, then calls `super.init()`
    required init?(coder: NSCoder) {
        var size: CGFloat = 24
        var image: NSImage = NSImage(size: NSSize(width: size, height: size))
        let font = NSFont.boldSystemFont(ofSize: size)
        let q = "?"
        let attributes: [NSAttributedStringKey: AnyObject] = [.font: font, .strokeColor: NSColor.white,
                                                              .foregroundColor: NSColor.black, .strokeWidth: NSNumber(value: -2)]
        image.lockFocus()
        q.draw(in: NSRect(x: 0, y: 0, width: size, height: size), withAttributes:attributes)
        image.unlockFocus()
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        size = 24
        let rotate = NSImage(named: (("rotate-icon.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        rotate.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        rotateCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        let resize = NSImage(named: (("4way-arrow.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        resize.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        resizeCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        super.init(coder: coder)
    }
    
    /// Required by the `Undo` protocol. Delegates the job to the controller.
    func reframePictureWithSize(_ node: SCNNode, newsize size: CGSize) {
        controller.reframePictureWithSize(node, newsize: size)
    }
    
    /// Register for drags of file names.
    override func awakeFromNib() {
        registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")])
        //acceptsTouchEvents = true
    }
    
    /// Returns the single scene camera node.
    func camera () -> SCNNode
    {
        return scene!.rootNode.childNode(withName: "Camera", recursively: false)!
    }
    
    /// Returns the omni light node
    func omniLight () -> SCNNode
    {
        return scene!.rootNode.childNode(withName: "Omni", recursively: false)!
    }
    
    /// Returns the ambient light node
    func ambientLight () -> SCNNode
    {
        return scene!.rootNode.childNode(withName: "Ambient", recursively: false)!
    }
    
    /// Returns the grid
    func grid()->SCNNode {
        return scene!.rootNode.childNode(withName: "Grid", recursively: false)!
    }
    
    /// Returns the floor
    func floor()->SCNNode {
        return scene!.rootNode.childNode(withName: "Floor", recursively: false)!
    }
    
    /// Hide the grid
    @objc func hideGrid(_ sender: AnyObject?) {
        grid().isHidden = true
    }
    
    /// Show the grid
    @objc func showGrid(_ sender: AnyObject?) {
        grid().isHidden = false
    }

    @objc func setPrintingCache(_ cache: [String: NSImage])
    {
        imageCacheForPrint = cache
    }
    
    /// Makes thumbnail images of each picture for the printed report.
    @objc func makePrintImageCache ()
    {
        var images: [String: NSImage] = [:]
        if let scene = scene {
            for picture in scene.rootNode.childNodes (passingTest: { x, yes in x.name == "Picture" }) {
                if let (name, image) = makeThumbnail(picture) {
                    images[name] = image
                }
            }
            self.performSelector(onMainThread: #selector(ArtSceneView.setPrintingCache(_:)), with: images, waitUntilDone: true)
        }
    }
    
    /// Add a wall to the scene
    
    func makeFakeWall()->SCNNode {
//        let plane = controller.makeGlass(NSSize(width: 100, height: 100))
        //                let fakeWall = SCNNode(geometry: plane)
        let wall = SCNPlane(width: 100, height: 100)
        let paint = SCNMaterial()
        paint.diffuse.contents = NSColor.clear
        paint.isDoubleSided = true
        //            paint.locksAmbientWithDiffuse = false
        //            paint.ambient.contents = NSColor.blackColor()
        wall.materials = [paint]
        let wallNode = SCNNode(geometry: wall)
        wallNode.name = "Fake"
//        wallNode.position.y = 50
        wallNode.castsShadow = false
        return wallNode
    }
    
    func makeWall(at: SCNVector3)->SCNNode {
        let wall = SCNPlane(width: controller.defaultWallSize.width, height: controller.defaultWallSize.height)
        let paint = SCNMaterial()
        paint.diffuse.contents = wallColor
        paint.isDoubleSided = true
        //            paint.locksAmbientWithDiffuse = false
        //            paint.ambient.contents = NSColor.blackColor()
        wall.materials = [paint]
        let wallNode = SCNNode(geometry: wall)
        wallNode.name = "Wall"
        wallNode.position = at
        wallNode.position.y = controller.defaultWallSize.height / 2.0
        wallNode.castsShadow = true
        let image = NSImage(named: ("Back.png" as NSString) as NSImage.Name)!
        let ratio = image.size.height / image.size.width
        image.size.width = 3.0
        image.size.height = image.size.width * ratio
        let back = controller.makeImage(image.copy() as! NSImage)
        back.name = "Back"
        back.position = SCNVector3(x: 0.0, y: 0.0, z: -0.1)
        wallNode.addChildNode(back)
        return wallNode
    }
    
    /// Displays info on some node in the status line.
    func getInfo(_ node: SCNNode) {
        guard let type = nodeType(node) else { return }
        var vNode = node
        switch type {
        case .Wall:
            let (size, location, rotation, distance) = wallInfo(node, camera: camera())
            controller.status = "Wall Size: \(size); Position: \(location); Rotation: \(rotation); Distance: \(distance!)"
        case .Matt:
            vNode = node.parent!
            fallthrough
        case .Picture:
            let (size, location) = pictureInfo(vNode)
            controller.status = "Picture Size: \(size); Position: \(location)"
        case .Image:
            let (size, name) = imageInfo(node)
            controller.status = "Image Size: \(size), Name: \(name)"
        default:
            break
        }
    }
    
    @IBAction func getInfo(_ sender: AnyObject?) {
        if case .getInfo = editMode {
            editMode = .none
            NSCursor.arrow.set()
        } else {
            editMode = .getInfo
            questionCursor.set()
        }
    }
    
    /// Delete all the pictures in the selection if the selection contains the mouseNode.
    /// Otherwise delete only the `mouseNode`.
    @IBAction func deletePictures(_ sender: AnyObject?)
    {
        if selection.count > 0 {
            undoer.setActionName("Delete Pictures")
            for picture in selection {
                changeParent(picture, from: picture.parent!, to: nil)
            }
            selection = []
        } else if let node = mouseNode, nodeType(node) == NodeType.Picture {
            undoer.setActionName("Delete Picture")
            changeParent(node, from: node.parent!, to: nil)
        }
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        if inDrag == true {
            guard let mouseNode = mouseNode else { return }
            switch editMode {
            case .resizing(.Picture, _):
                let size = snapToGrid(mouseNode.size()!)
                controller.doChangePictureSize(mouseNode, from: saved as! CGSize, to: size)
                let (newsize, _) = pictureInfo(mouseNode)
                controller.status = "Picture Size: \(newsize)"
            case .resizing(.Image, _):
                let size = snapToGrid(mouseNode.childNode(withName: "Image", recursively: false)!.size()!)
                controller.doChangeImageSize(mouseNode, from: saved as! CGSize, to: size)
                let (newsize, name) = imageInfo(mouseNode)
                controller.status = "\(name): \(newsize)"
            case .resizing(.Wall, _):
                if wallsLocked {
                    break
                }
                let (oldSize, oldPosition) = saved as! (CGSize, SCNVector3)
                let currentSize = mouseNode.size()!
                let newSize = snapToGrid(mouseNode.size()!)
                changeSize(mouseNode, from: oldSize, to: newSize)
                let delta = CGSize(width: newSize.width - currentSize.width,
                                   height: newSize.height - currentSize.height)
                let translate = simd_make_float3(Float(delta.width / 2.0),
                                                 Float(delta.height / 2.0),
                                                 0.0)
                mouseNode.simdLocalTranslate(by: translate)
                changePosition(mouseNode, from: oldPosition, to: mouseNode.position)
                for child in mouseNode.childNodes {
                    if nodeType(child) == .Picture {
                        child.position.y -= delta.height / 2.0
                    }
                }
                let (newsize, _, _, _) = wallInfo(mouseNode)
                controller.status = "Wall Size: \(newsize)"
            case .moving(.Picture):
                for (node, oldPosition, parent) in saved as! [(SCNNode, SCNVector3, SCNNode)] {
                    let position = snapToGrid(node.position)
                    changePosition(node, from: oldPosition, to: position)
                    changeParent(node, from: parent, to: node.parent!)
                }
                showNodePosition(mouseNode)
            case .moving(.Wall):
                if !wallsLocked {
                    let position = snapToGrid(mouseNode.position)
                    changePosition(mouseNode, from: saved as! SCNVector3, to: position)
                }
            default: ()
            }
            undoer.endUndoGrouping()
        }
        
        inDrag = false
        // Remove the false wall.
        if let child = mouseNode?.childNode(withName: "Fake", recursively: false) {
            child.removeFromParentNode()
        }
        mouseNode = nil
        flagsChanged(with: theEvent)
    }
    
    /// Sets `mouseNode`, `editMode`, and the cursor image based on the the the first node in the
    /// sorted list of hits returned from `hitTest`.
    override func mouseMoved(with theEvent: NSEvent) {
        if inDrag { return }
        let p = theEvent.locationInWindow
        mouseNode = nil
        switch editMode {
        case .selecting, .getInfo, .resizing(.Image, _): break
        default:
            editMode = .none
        }
        lastYLocation = p.y
        if NSPointInRect(p, frame) {
            var hitResults = self.hitTest(p, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
            hitResults = hitResults.filter({ nodeType($0.node) != .Back})
            if hitResults.count > 0 {
                let hit = hitResults[0]
                switch editMode {
                case .getInfo:
                    mouseNode = hit.node
                    return
                case .selecting:
                    mouseNode = parent(hit.node, ofType: .Picture)
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
                    case .Matt, .Image:
                        fallthrough
                    case .Picture:
                        mouseNode = parent(hit.node, ofType: .Picture)
                        let altAlone = theEvent.modifierFlags.rawValue & NSEvent.ModifierFlags.option.rawValue != 0
                        if !altAlone {
                            editMode = .moving(.Picture)
                            NSCursor.openHand.set()
                        }
                    case .Wall:
                        if wallsLocked {
                            NSCursor.arrow.set()
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
                    default:
                        mouseNode = nil
                        editMode = .none
                        NSCursor.arrow.set()
                    }
                }
            } else {
                mouseNode = nil
                editMode = .none
                NSCursor.arrow.set()
                super.mouseMoved(with: theEvent)
            }
        } else {
            NSCursor.arrow.set()
            super.mouseMoved(with: theEvent)
        }
    }
    
    /// Sets the status line from the position of `node`.
    func showNodePosition(_ node: SCNNode) {
        let wall = node.parent
        let plane = wall?.geometry as! SCNPlane
        let x: CGFloat = node.position.x + plane.width / 2.0
        let y: CGFloat = node.position.y + plane.height / 2.0
        let xcoord = convertToFeetAndInches(x)
        let ycoord = convertToFeetAndInches(y)
        controller.status = "Picture Position: \(xcoord), \(ycoord)"
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

        
        // Weird special case. If the wall width is being resized, and the resizer overlaps
        // another wall in front of the resized wall, that other wall becomes the wallHit,
        // and the delta is wrong. So if we are not dragging on the original wall, then
        // we want to be dragging over the false wall. The false wall is a subnode of the
        // mouseNode with the name "Wall"
        if let theHit = wallHit, case .resizing(.Wall, _) = editMode, theHit.node != mouseNode {
            let falseHit = hitResults.filter( { $0.node.parent == mouseNode && $0.node.name == "Wall" } )
            if !falseHit.isEmpty {
                wallHit = falseHit[0]
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
            let (newsize, _) = pictureInfo(mouseNode)
            controller.status = "Picture Size: \(newsize)"
        case .resizing(.Image, _):
            var size = mouseNode.childNode(withName: "Image", recursively: false)!.size()!
            let dy = delta.y
            let dx = dy * size.width / size.height
            size = CGSize(width: size.width + dx, height: size.height + dy)
            controller.reframeImageWithSize(mouseNode, newsize: size)
            let (newsize, name) = imageInfo(mouseNode)
            controller.status = "\(name): \(newsize)"
        case .moving(.Wall):
            if wallsLocked {
                break
            }
            SCNTransaction.animationDuration = 0.2
            let shift = theEvent.modifierFlags.contains(.shift)
            let scale: CGFloat = shift ? 40.0 : 10.0
            let size = CGSize(width: theEvent.deltaX / scale, height: theEvent.deltaY / scale)
            moveNode(size.height, deltaRight: -size.width, node: mouseNode, angle: camera().eulerAngles.y)
            let (_, location, _, distance) = wallInfo(wall, camera: camera())
            controller.status = "Wall Location: \(location); Camera distance: \(distance!)"
        case .resizing(.Wall, let edge):
            if wallsLocked {
                break
            }
            if let geometry = mouseNode.geometry as? SCNPlane {
                SCNTransaction.animationDuration = 0.0
                var factor: Float = 1.0
                let dy: CGFloat = { switch edge {
                    case .top: return delta.y
                    case .bottom: return -delta.y
                    default: return 0 }
                    }()
                let dx: CGFloat = { switch edge {
                    case .right: return delta.x
                    case .left:
                        factor = -1.0
                        return -delta.x
                    default: return 0 }
                    }()
                let newSize = CGSize(width: geometry.width + dx, height: geometry.height + dy)
                // The wall must enclose all the pictures
                if newSize.width >= 0.5 && newSize.height >= 0.5
                    && wallContainsPictures(mouseNode, withNewSize: newSize)
                {
                    geometry.width = newSize.width
                    geometry.height = newSize.height
                    let translate = simd_make_float3(factor * Float(dx / 2.0), factor * Float(dy / 2.0), 0.0)
                    mouseNode.simdLocalTranslate(by: translate)
                    for child in mouseNode.childNodes {
                        if let type = nodeType(child) {
                            switch type {
                            case .Picture:
                                child.position.y -= dy / 2
                            case .Wall:
                                break
                            default: ()
                            }
                        }
                    }
                    let (newsize, _, _, _) = wallInfo(mouseNode)
                    controller.status = "Wall Size: \(newsize)"
                }
            }
         default:
            editMode = .none
        }
        lastMousePosition = currentMousePosition
   }
    
    /// Switches according to `editMode`.
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        controller.editMode = .none
       if mouseNode == nil {
            for node in selection {
                setNodeEmission(node, color: NSColor.black)
            }
            selection = []
            editMode = .none
            return
        }
        guard let mouseNode = mouseNode else { return }
        let p = theEvent.locationInWindow
        let hitResults = self.hitTest(p, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
        guard hitResults.count > 0 else {
            return
        }
        if nodeType(hitResults[0].node) == .Back {
            return
        }
        switch editMode {
        case .getInfo:
            getInfo(mouseNode)
        case .moving(.Wall):
            if wallsLocked {
                break
            }
            prepareForUndo(mouseNode)
            inDrag = true
            NSCursor.closedHand.set()
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
            if wallsLocked {
                break
            }
            // Make a gigantic transparent wall coplanar with `mouseNode` so that the mouse can be off
            // the wall while dragging it larger.
                prepareForUndo(mouseNode)
                inDrag = true
                let fakeWall = makeFakeWall()
                mouseNode.addChildNode(fakeWall)
        case .resizing(.Picture, _):
            prepareForUndo(mouseNode)
            inDrag = true
       case .resizing(.Image, _):
                prepareForUndo(mouseNode)
                inDrag = true
        default:
            editMode = .none
        }
    }
    
    override func keyDown(with theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers {
            if keyString == "+" {
                camera().camera?.fieldOfView += 2.0
                controller.updateCameraStatus()
            } else if keyString == "-" {
                camera().camera?.fieldOfView -= 2.0
                controller.updateCameraStatus()
            } else {
                controller.keyDown(with: theEvent)
            }
        } else {
            controller.keyDown(with: theEvent)
        }
    }
    
// MARK: Interapplication dragging.
    
    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let hits = hitTest(sender.draggingLocation(), options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
        guard let wallHit = hitOfType(hits, type: .Wall) else {
            controller.status = "No Wall Under Mouse"
            return NSDragOperation()
        }
        let target = wallHit.localCoordinates
        let plane = wallHit.node.geometry as! SCNPlane
        let x = convertToFeetAndInches(target.x + plane.width / 2)
        let y = convertToFeetAndInches(target.y + plane.height / 2)
        controller.status = "Drop at \(x), \(y)"
        return NSDragOperation.copy
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if NSImage.canInit(with: sender.draggingPasteboard()) {
            return NSDragOperation.copy
        } else {
            return NSDragOperation()
        }
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return NSImage.canInit(with: sender.draggingPasteboard())
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var result = false
        let pasteboard = sender.draggingPasteboard()
        if let plist = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray
            {
                let path = plist[0] as! String
                var point = sender.draggingLocation()
                point = convert(point, from: nil)
                let hitResults = self.hitTest(point, options: [SCNHitTestOption.searchMode: NSNumber(value: 1)])
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
    
}
