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
            Thread.detachNewThreadSelector(Selector("makePrintImageCache"),
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
    
    /// Makes the `questionCursor` and `rotateCursor`, then calls `super.init()`
    required init?(coder: NSCoder) {
        var size: CGFloat = 24
        var image: NSImage = NSImage(size: NSSize(width: size, height: size))
        let font = NSFont.boldSystemFont(ofSize: size)
        let q = "?"
        let attributes = [NSFontAttributeName: font, NSStrokeColorAttributeName: NSColor.white,
            NSForegroundColorAttributeName: NSColor.black, NSStrokeWidthAttributeName: -2]
        image.lockFocus()
        q.draw(in: NSRect(x: 0, y: 0, width: size, height: size), withAttributes:attributes)
        image.unlockFocus()
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 0, y: 0))
        
        size = 24
        let rotate = NSImage(named: "rotate-icon.png")!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        rotate.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        rotateCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 0, y: 0))
        super.init(coder: coder)
    }
    
    /// Required by the `Undo` protocol. Delegates the job to the controller.
    func reframePictureWithSize(_ node: SCNNode, newsize size: CGSize) {
        controller.reframePictureWithSize(node, newsize: size)
    }
    
    /// Register for drags of file names.
    override func awakeFromNib() {
        register(forDraggedTypes: [NSFilenamesPboardType])
        acceptsTouchEvents = true
    }
    
    /// Returns the single scene camera.
    func camera () -> SCNNode
    {
        return scene!.rootNode.childNode(withName: "Camera", recursively: false) as SCNNode!
    }
    
    func setPrintingCache(_ cache: [String: NSImage])
    {
        imageCacheForPrint = cache
    }
    
    /// Makes thumbnail images of each picture for the printed report.
    func makePrintImageCache ()
    {
        var images: [String: NSImage] = [:]
        if let scene = scene {
            for picture in scene.rootNode.childNodes (passingTest: { x, yes in x.name == "Picture" }) {
                if let (name, image) = makeThumbnail(picture) {
                    images[name] = image
                }
            }
            self.performSelector(onMainThread: Selector("setPrintingCache:"), with: images, waitUntilDone: true)
        }
    }
    
    /// Displays info on some node in the status line.
    func getInfo(_ node: SCNNode) {
        var node = node
        if node.name == NodeType.Image.rawValue {
            node = node.parent!
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
    
    /// Delete all the pictures in the selection if the selection contains the mouseNode.
    /// Otherwise delete only the `mouseNode`.
    @IBAction func deletePictures(_ sender: AnyObject?)
    {
        if let mouseNode = mouseNode {
            if selection.contains(mouseNode) {
                undoer.setActionName("Delete Pictures")
                for picture in selection {
                    setParentOf(picture, to: nil)
                }
                selection = []
            } else {
                undoer.setActionName("Delete Picture")
                setParentOf(mouseNode, to: nil)
            }
        }
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        if inDrag == true {
            undoer.endUndoGrouping()
        }
        
        inDrag = false
        // Remove the false wall.
        if let child = mouseNode?.childNode(withName: "Wall", recursively: false) {
            child.removeFromParentNode()
        }
        mouseNode = nil
        if case .getInfo = editMode {
        } else {
            controller.status = ""
        }
        flagsChanged(with: theEvent)
    }
    
    /// Sets `mouseNode`, `editMode`, and the cursor image based on the the the first node in the
    /// sorted list of hits returned from `hitTest`.
    override func mouseMoved(with theEvent: NSEvent) {
        if inDrag {
            return
        }
        
        switch editMode {
        case .getInfo, .selecting, .contextualMenu:
            return
        default:
            break
        }

        editMode = .none
//        mouseHit = nil
        mouseNode = nil
        let p = theEvent.locationInWindow
        lastYLocation = p.y
        if NSPointInRect(p, frame) {
            let hitResults = self.hitTest(p, options: [SCNHitTestOption.firstFoundOnly: false, SCNHitTestOption.sortResults: true])
            if hitResults.count > 0 {
                if let wallHit = hitOfType(hitResults, type: .Wall) {
                    lastMousePosition = wallHit.localCoordinates
                }
                let hit = hitResults[0]
//                mouseHit = hit
                mouseNode = hit.node
                if let type = nodeType(hit.node) {
                    switch type {
                    case .Left, .Right:
                        mouseNode = parent(mouseNode!, ofType: .Picture)
                        let edge: NodeEdge = type == .Left ? .left : .right
                        editMode = .resizing(.Picture, edge)
                        NSCursor.resizeLeftRight().set()
                    case .Top, .Bottom:
                        mouseNode = parent(mouseNode!, ofType: .Picture)
                        editMode = .resizing(.Picture, type == .Top ? .top : .bottom)
                        NSCursor.resizeUpDown().set()
                    case .Matt, .Image:
                        mouseNode = parent(mouseNode!, ofType: .Picture)
                        fallthrough
                    case .Picture:
                        editMode = .moving(.Picture)
                        NSCursor.openHand().set()
                    case .Wall:
                        let local = NSPoint(x: hit.localCoordinates.x, y: hit.localCoordinates.y)
                        let node = hit.node
                        let size = nodeSize(node)
                        let width2 = size.width / 2
                        let height2 = size.height / 2
                        let cusp: CGFloat = 0.5
                        var rect = NSRect(x: -width2, y: -height2, width: cusp, height: size.height)
                        if NSPointInRect(local, rect) {
                            editMode = .resizing(.Wall, .left)
                            NSCursor.resizeLeftRight().set()
                        } else {
                            rect = NSRect(x: width2 - cusp, y: -height2, width: cusp, height: size.height)
                            if NSPointInRect(local, rect) {
                                editMode = .resizing(.Wall, .right)
                                NSCursor.resizeLeftRight().set()
                            } else {
                                rect = NSRect(x: -width2, y: height2 - cusp, width: size.width, height: cusp)
                                if NSPointInRect(local, rect) {
                                    editMode = .resizing(.Wall, .top)
                                    NSCursor.resizeUp().set()
                                } else {
                                    rect = NSRect(x: -width2, y: -height2, width: size.width, height: cusp)
                                    if NSPointInRect(local, rect) {
                                        editMode = .resizing(.Wall, .pivot)
                                        rotateCursor.set()
                                    } else {
                                        editMode = .moving(.Wall)
                                        NSCursor.openHand().set()
                                    }
                                }
                            }
                        }
                    default:
                        NSCursor.arrow().set()
                    }
                }
            } else {
                mouseNode = nil
//                mouseHit = nil
                NSCursor.arrow().set()
                super.mouseMoved(with: theEvent)
            }
        } else {
            NSCursor.arrow().set()
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
    

    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setPosition1(_ args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let v = args["position"] as! [CGFloat]
        let vec = SCNVector3(x: v[0], y: v[1], z: v[2])
        setPosition(node, position: vec)
    }

    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setPivot1(_ args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let angle = args["angle"] as! CGFloat
        setPivot(node, angle: angle)
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setNodeSize1(_ args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let v = args["size"] as! [CGFloat]
        setNodeSize(node, size: CGSize(width: v[0], height: v[1]))
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setParentOf1(_ args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let parent = args["parent"] as? SCNNode
        setParentOf(node, to: parent)
    }
    
    /// Based on `editMode` and `mouseNode`, perform a drag operation, either resizing,
    /// moving, or rotating a wall.
    override func mouseDragged(with theEvent: NSEvent) {
        guard let mouseNode = mouseNode else { return }
        
        if !inDrag {
            controller.editMode = .none
            prepareForUndo(mouseNode)
        }
        inDrag = true
        
        let p = theEvent.locationInWindow
        
        // Handle the rotate operation separately, since there may not be a hit node, which is
        // not required to rotate.
        if case .resizing(.Wall, .pivot) = editMode {
            let dy = p.y - lastYLocation
            lastYLocation = p.y
            mouseNode.eulerAngles.y += dy / 100
            let (_, _, rotation, _) = wallInfo(mouseNode)
            controller.status = "Wall Rotation: \(rotation)"
            return
        }

        // Find a hit node or bail.
        let hitResults = self.hitTest(p, options: nil)
        SCNTransaction.animationDuration = 0.0
        guard var wallHit = hitOfType(hitResults, type: .Wall) else {
            return
        }
        
        // Weird special case. If the wall width is being resized, and the resizer overlaps
        // another wall in front of the resized wall, that other wall becomes the wallHit,
        // and the delta is wrong. So if we are not dragging on the original wall, then
        // we want to be dragging over the false wall. The false wall is a subnode of the
        // mouseNode with the name "Wall"
        if case .resizing(.Wall, _) = editMode where wallHit.node != mouseNode {
            let falseHit = hitResults.filter( { $0.node.parent == mouseNode && $0.node.name == "Wall" } )
            if !falseHit.isEmpty {
                wallHit = falseHit[0]
            }
        }
        
        let wall = wallHit.node
        let currentMousePosition = wallHit.localCoordinates
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
                    setParentOf(node, to: wall)
                }
                if node === mouseNode {
                    showNodePosition(node)
                }
            }
        case .resizing(.Picture, let edge):
            if let geometry = mouseNode.geometry as? SCNPlane {
                let dy: CGFloat = { switch edge {
                    case .top: return delta.y
                    case .bottom: return -delta.y
                    default: return 0 }
                }()
                let dx: CGFloat = { switch edge {
                    case .right: return delta.x
                    case .left: return -delta.x
                    default: return 0 }
                }()
                let size = CGSize(width: geometry.width + dx, height: geometry.height + dy)
                controller.reframePictureWithSize(mouseNode, newsize: size)
                let (newsize, _, _) = pictureInfo(mouseNode)
                controller.status = "Picture Size: \(newsize)"
            }
        case .moving(.Wall):
            SCNTransaction.animationDuration = 0.2
            let shift = theEvent.modifierFlags.contains(.shift)
            let scale: CGFloat = shift ? 40.0 : 10.0
            let dx = theEvent.deltaX / scale
            let dy = theEvent.deltaY / scale
            moveNode(dy, deltaRight: -dx, node: mouseNode)
            let (_, location, _, distance) = wallInfo(wall, camera: camera())
            controller.status = "Wall Location: \(location); Camera distance: \(distance!)"
        case .resizing(.Wall, let edge):
            if let geometry = mouseNode.geometry as? SCNPlane {
                SCNTransaction.animationDuration = 0.0
                let dy: CGFloat = { switch edge {
                    case .top: return delta.y
                    case .bottom: return -delta.y
                    default: return 0 }
                    }()
                let dx: CGFloat = { switch edge {
                    case .right: return delta.x
                    case .left: return -delta.x
                    default: return 0 }
                    }()
                // The wall must enclose all the pictures
                if wallContainsPictures(mouseNode, withNewSize: CGSize(width: geometry.width + dx,
                    height: geometry.height + dy)) {
                        geometry.width += dx
                        geometry.height += dy
                        mouseNode.position.y += dy / 2
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
            break
        }
        lastMousePosition = currentMousePosition
   }
    
    /// Switches according to `editMode`.
    override func mouseDown(with theEvent: NSEvent) {
        /* Called when a mouse click occurs */
        controller.editMode = .none
        
        let p = theEvent.locationInWindow
        let hitResults = self.hitTest(p, options: nil)
        guard hitResults.count > 0 else { return }
        switch editMode {
        case .getInfo:
            getInfo(hitResults[0].node)
        case .selecting:
            guard let node = hitOfType(hitResults, type: .Picture)?.node
                else {
                    for node in selection {
                        setNodeEmission(node, color: NSColor.black)
                    }
                    selection = []
                    break
            }
            let pictureNodes = Set([node])
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
            // Make a gigantic transparent wall coplanar with `mouseNode` so that the mouse can be off
            // the wall while dragging it larger.
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
    
// MARK: Interapplication dragging.
    
    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let hits = hitTest(sender.draggingLocation(), options: nil)
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
        if let plist = pasteboard.propertyList(forType: NSFilenamesPboardType) as! NSArray?
            where plist.count > 0 {
                let path = plist[0] as! String
                var point = sender.draggingLocation()
                point = convert(point, from: nil)
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
    
}
