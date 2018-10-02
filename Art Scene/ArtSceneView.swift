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
    
    override var frame: NSRect {
        didSet {
            controller.frameSizeChanged = true
        }
    }

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
    
    /// The Heads Up Display hosted in an SKScene
    var hud: HUD!
    
    /// The set of selected pictures. The first picture selected is always the `masterNode`.
    var selection: Array<SCNNode>  = []
    
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
    /// The chair curson
    let chairCursor: NSCursor
    var currentCursor: NSCursor?
    var wallsLocked: Bool {
        return controller.wallsLocked
    }
    
    // A hack to restore the hidden state of the picture after moving.
    var frameWasHidden: Bool = false
    
    /// Returns the ambient light node
    @objc var ambientLight: SCNNode? {
        get {
           return scene?.rootNode.childNode(withName: "Ambient", recursively: false)!
        }
    }
            
    /// Returns the omni light node
    @objc var omniLight: SCNNode? {
        get {
            return scene?.rootNode.childNode(withName: "Omni", recursively: false)!
        }
    }
    
    @objc var ambientLightIntensity: CGFloat {
        set {
            ambientLight!.light?.color = NSColor(white: newValue, alpha: 1.0)
        }
        get {
            var color = (ambientLight!.light?.color as! NSColor)
            if #available(OSX 10.14, *) {
                color = color.usingColorSpaceName(NSColorSpaceName.calibratedWhite)!
            }
            return color.whiteComponent
        }
    }
    
    @objc var omniLightIntensity: CGFloat {
        set {
            omniLight!.light?.color = NSColor(white: newValue, alpha: 1.0)
        }
        get {
            var color = (omniLight!.light?.color as! NSColor)
            if #available(OSX 10.14, *) {
                color = color.usingColorSpaceName(NSColorSpaceName.calibratedWhite)!
            }
            return color.whiteComponent
        }
    }
    
    @objc var spotlightIntensity: CGFloat = -1.0 {
        didSet {
            scene?.rootNode.enumerateChildNodes({ (node: SCNNode, stop) in
                if node.light != nil && node.light!.type == .spot {
                    node.light!.color = NSColor(white: spotlightIntensity, alpha: 1.0)
                }
                
            })
        }
    }
    
    /// Makes the `questionCursor` and `rotateCursor`, then calls `super.init()`
    required init?(coder: NSCoder) {
        var size: CGFloat = 24
        let font = NSFont.boldSystemFont(ofSize: size)
        let q = "?"
        let attributes: [NSAttributedStringKey: AnyObject] = [.font: font, .strokeColor: NSColor.white,
                                                              .foregroundColor: NSColor.black, .strokeWidth: NSNumber(value: -2)]
        let qSize = (q as NSString).size(withAttributes: attributes)
        var image: NSImage = NSImage(size: NSSize(width: qSize.width + 2, height: qSize.height + 2))
        image.lockFocus()
        q.draw(in: NSRect(x: 1, y: -7, width: qSize.width, height: qSize.height), withAttributes:attributes)
        image.unlockFocus()
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: qSize.width / 2.0, y: qSize.height))
        
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
        
        let chair = NSImage(named: (("noun_Chair_138821.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        chair.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        chairCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        super.init(coder: coder)
    }
    
    @IBAction func resetCamera(_ sender: AnyObject)
    {
        camera().rotation = SCNVector4Zero
        camera().position = SCNVector3Make(0.0, 6.0, 0.0)
    }
    
    /// Required by the `Undo` protocol. Delegates the job to the controller.
    func reframePictureWithSize(_ node: SCNNode, newsize size: CGSize) {
        controller.reframePictureWithSize(node, newsize: size)
    }
    
    /// Register for drags of file names.
    override func awakeFromNib() {
        hud = HUD(size: frame.size, controller: controller)
        overlaySKScene = hud
        registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")])
        if #available(OSX 10.12, *) {
        }

    }
    
    /// Returns the single scene camera node.
    func camera () -> SCNNode
    {
        return scene!.rootNode.childNode(withName: "Camera", recursively: false)!
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
    
    @IBAction func daySky(_ sender: AnyObject)
    {
        let skybox = NSImage.Name(rawValue: "miramar.jpg")
        let path = Bundle.main.pathForImageResource(skybox)!
        let image = NSImage(contentsOfFile: path)
         scene!.background.contents = image
    }
    
    @IBAction func nightSky(_ sender: AnyObject)
    {
        let skybox = NSImage.Name(rawValue: "purplenebula.png")
        let path = Bundle.main.pathForImageResource(skybox)!
        let image = NSImage(contentsOfFile: path)
        scene!.background.contents = image
    }
    
    @IBAction func graySky(_ sender: AnyObject)
    {
        scene!.background.contents = NSColor.lightGray
    }
    
    @IBAction func blackSky(_ sender: AnyObject)
    {
        scene!.background.contents = nil
    }
    
    @IBAction func shadows(_ sender: NSMenuItem)
    {
        if let omni = omniLight!.light {
            if omni.castsShadow {
                omni.castsShadow = false
                sender.title = "Shadow"
            } else {
                omni.castsShadow = true
                sender.title = "No Shadow"
            }
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(ArtSceneView.shadows(_:)) {
            if omniLight?.light?.castsShadow == true {
                menuItem.title = "No Shadows"
            } else {
                menuItem.title = "Shadows"
            }
        }
        return true
    }

    /// Displays info on some node in the status line.
    func getInfo(_ node: SCNNode, option: Bool = false, hitPosition: SCNVector3? = nil) {
        var vNode = node
        if !option && nodeType(node) == .Image {
            vNode = pictureOf(node)!
        }
        guard let type = nodeType(vNode) else { return }
        var hudTable: [(String, String)] = []
        var title: String = ""
        switch type {
        case .Wall:
            let (x, y, width, height, rotation, distance) = wallInfo(node, camera: camera(), hitPosition: hitPosition)
            hudTable = [("↔", x), ("↕", y), ("width", width), ("height", height), ("y°", rotation), ("↑", distance!)]
            title = "Wall"
        case .Matt:
            vNode = node.parent!
            fallthrough
        case .Picture:
            let (x, y, width, height, hidden, distance) = pictureInfo(vNode, camera: camera(), hitPosition: hitPosition)
            hudTable = [("↔", x), ("↕", y), ("width", width), ("height", height),
                        ("frame", hidden),
                        ("↑", distance)]
            title = "Picture"
        case .Image:
            let (width, height, name) = imageInfo(vNode)
            hudTable = [("width", width), ("height", height)]
            title = name
        case .Box, .Chair, .Table:
            let (x, y, width, height, length, rotation) = boxInfo(node)
            hudTable = [("↔", x), ("↕", y), ("width", width), ("length", length), ("height", height), ("y°", rotation)]
            title = "\(String(describing: node.name!))"

        default:
            return
        }
        controller.hudUpdate = controller.makeDisplay(title: title, items: hudTable, width: fontScaler * 220)
        isPlaying = true
    }
    
    @IBAction func getTheInfo(_ sender: AnyObject?) {
        if case .getInfo = editMode {
            editMode = .none
            let display = overlaySKScene?.childNode(withName: "HUD Display")
            display?.run(SKAction.fadeOut(withDuration: 1.0))
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
        undoer.beginUndoGrouping()
        if selection.count > 0 {
            undoer.setActionName("Delete Pictures")
            for picture in selection {
                changeParent(picture, to: nil)
            }
            selection = []
        } else if let node = mouseNode, nodeType(node) == NodeType.Picture {
            undoer.setActionName("Delete Picture")
            changeParent(node, to: nil)
        }
        undoer.endUndoGrouping()
    }
    
    /// Sets the status line from the position of `node`.
    func showNodePosition(_ node: SCNNode) {
        let wall = node.parent
        let plane = wall?.geometry as! SCNPlane
        let x: CGFloat = node.position.x + plane.width / 2.0
        let y: CGFloat = node.position.y + plane.height / 2.0
        let xcoord = convertToFeetAndInches(x)
        let ycoord = convertToFeetAndInches(y)
        let display = controller.makeDisplay(title: "Picture",
                                     items: [("x", xcoord), ("y", ycoord)],
                                     width: 175)
        display.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
        controller.hudUpdate = display
    }
    
// MARK: Interapplication dragging.
    
    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let hits: [SCNHitTestResult]
        if #available(OSX 10.13, *) {
            hits = hitTest(sender.draggingLocation(), options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
        } else {
            hits = hitTest(sender.draggingLocation(), options: nil)
        }
        
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
                let hitResults: [SCNHitTestResult]
                if #available(OSX 10.13, *) {
                    hitResults = hitTest(point, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
                } else {
                    hitResults = hitTest(point, options: nil)
                }
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
