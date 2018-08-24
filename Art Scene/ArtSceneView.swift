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
    
    /// The Art Scene document
    @IBOutlet weak var document: Document!
    /// The location of the last mouse click that generated a contextual menu.
    var mouseClickLocation: SCNVector3? = nil
    /// The documents undo manager
    var undoer:UndoManager {
        get { return document!.undoManager! }
    }
    
    /// The set of selected pictures. The first picture selected is always the `masterNode`.
    var selection: Array<SCNNode>  = []
    
    /// The last mouse position as determined during `mouseMoved`.
    var lastMousePosition: SCNVector3? = nil
    /// Used while dragging to rotate a wall. The mouse y coordinate is used since
    /// the mouse may not be over a wall or picture during the drag.
    var lastYLocation: CGFloat = 0.0
    /// Accumulate deltas here.
    var deltaSum: CGPoint!
    
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
    var currentCursor: NSCursor?
    var wallsLocked: Bool {
        return controller.wallsLocked
    }
        
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
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 21))
        
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

    /// Add a wall to the scene
    
   /// Displays info on some node in the status line.
    func getInfo(_ node: SCNNode, option: Bool = false, hitPosition: SCNVector3? = nil) {
        var vNode = node
        if !option && nodeType(node) == .Image {
            vNode = picture(node)!
        }
        guard let type = nodeType(vNode) else { return }
        switch type {
        case .Wall:
            let (size, location, rotation, distance) = wallInfo(node, camera: camera(), hitPosition: hitPosition)
            controller.status = "Wall: {\(size)} at (\(location)), \(rotation); \(distance!) away"
        case .Matt:
            vNode = node.parent!
            fallthrough
        case .Picture:
            let (size, location, hidden, distance) = pictureInfo(vNode, camera: camera(), hitPosition: hitPosition)
            let extra = hidden ? ", frame hidden" : ""
            let extra2 = distance.count > 0 ? " \(distance) away" : ""
            controller.status = "(\(size)) at {\(location)}\(extra);\(extra2)"
        case .Image:
            let (size, name) = imageInfo(vNode)
            controller.status = "\(name): \(size)"
        default:
            break
        }
    }
    
    @IBAction func getTheInfo(_ sender: AnyObject?) {
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
    
    /// Sets the status line from the position of `node`.
    func showNodePosition(_ node: SCNNode) {
        let wall = node.parent
        let plane = wall?.geometry as! SCNPlane
        let x: CGFloat = node.position.x + plane.width / 2.0
        let y: CGFloat = node.position.y + plane.height / 2.0
        let xcoord = convertToFeetAndInches(x)
        let ycoord = convertToFeetAndInches(y)
        controller.status = "Position: \(xcoord), \(ycoord)"
    }
    

// MARK: Interapplication dragging.
    
    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let hits = hitTest(sender.draggingLocation(), options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
        guard let wallHit = hitOfType(hits, type: .Wall) else {
            controller.status = "No Wall Under Mouse"
            return NSDragOperation()
        }
        let target = wallHit.localCoordinates
        let plane = wallHit.node.geometry as! SCNPlane
        deltaSum = CGPoint.zero
        let (x1, y1) = snapToGrid(d1: target.x + plane.width / 2, d2: target.y + plane.height / 2, snap: gridFactor)
        let x = convertToFeetAndInches(x1)
        let y = convertToFeetAndInches(y1)
        controller.status = "Drop at {\(x), \(y)}"
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
                let hitResults = self.hitTest(point, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
                if hitResults.count > 0 {
                    if let pictureHit = hitOfType(hitResults, type: .Picture) {
                        result = true
                        controller.replacePicture(pictureHit.node, path: path)
                    } else if let wallHit = hitOfType(hitResults, type: .Wall) {
                        result = true
                        deltaSum = CGPoint.zero
                        var coordinates = wallHit.localCoordinates
                        let (x, y) = snapToGrid(d1: coordinates.x, d2: coordinates.y, snap: gridFactor)
                        coordinates.x = x
                        coordinates.y = y
                        controller.addPicture(wallHit.node, path: path, point: coordinates)
                    }
                
                }
        }
        
        return result
    }
    
}
