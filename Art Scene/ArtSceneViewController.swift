//
//  GameViewController.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import Quartz

/**
The view controller for an ArtSceneView. Handles moving, resizing, and rotating by
using the arrow keys.
*/
class ArtSceneViewController: NSViewController, Undo {
    
    @IBOutlet weak var artSceneView: ArtSceneView!
    @IBOutlet weak var document: Document?
    /// The status bar is a text field at the top of the window.
    @IBOutlet weak var statusBar: NSTextField!
    
    /// `true` if the controller is prepared for undo. The controller opens an undo grouping
    /// when key based editing begins. A change in `editMode` triggers an end to that grouping.
    var preparedForUndo: Bool = false
    
    var editMode = EditMode.None {
        willSet(newMode) {
            status = ""
            if case EditMode.None = newMode where preparedForUndo {
                undoer.endUndoGrouping()
                preparedForUndo = false
            }
        }
    }
    
    var defaultFrameSize: CGSize = CGSize(width: 2, height: 2)
    /// The target of key-based editing, either a picture or a wall.
    var theNode: SCNNode? = nil
    var undoer:NSUndoManager {
        get { return (document?.undoManager)! }
    }

    dynamic var status: NSString = ""
    
    /// The standard frame sizes.
    let frameSizes = ["16x16":  CGSize(width: 16, height: 16),
        "16x20":  CGSize(width: 16, height: 20),
        "20x16":  CGSize(width: 20, height: 16),
        "20x20":  CGSize(width: 20, height: 20),
        "20x24":  CGSize(width: 20, height: 24),
        "24x20":  CGSize(width: 24, height: 20),
        "24x24":  CGSize(width: 24, height: 24)]
    
    /// Required by the Undo protocol. Use the view's selection.
    var selection: Set<SCNNode> {
        get { return artSceneView.selection }
        set { artSceneView.selection = newValue }
    }
    
    @IBAction func hideStatus(sender: AnyObject) {
        status = ""
    }
    
    override func awakeFromNib(){
        NSBundle.mainBundle().loadNibNamed("ActionMenu", owner: artSceneView, topLevelObjects: nil)
        
        // create a new scene
        
        // allows the user to manipulate the camera
        self.artSceneView!.allowsCameraControl = false
        
        // show statistics such as fps and timing information
        self.artSceneView!.showsStatistics = false
        
        // configure the view
        self.artSceneView!.backgroundColor = NSColor.blackColor()
        
        let window = artSceneView!.window!
        window.acceptsMouseMovedEvents = true;
        window.makeFirstResponder(artSceneView)
        
        // Clicking in the menu bar ends the undo group.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("menuBarClicked:"),
            name: NSMenuDidBeginTrackingNotification, object: NSApp.mainMenu)
    }
    
    /// A menu action to reframe a picture to one of the standard sizes.
    func reframePicture(sender: AnyObject?)
    {
        if let sender = sender as? NSMenuItem {
            let title = sender.title
            defaultFrameSize = frameSizes[title]!
            defaultFrameSize.width /= 12
            defaultFrameSize.height /= 12
            reframePictureWithSize(theNode!, newsize: defaultFrameSize)
        }
    }
    
    /// Add a picture based on an image from the path at a given location.
    func addPicture(wall: SCNNode, path: String, point: SCNVector3, size: CGSize = CGSize.zero) -> SCNNode? {
        if let node = makePicture(path, size: size) {
            undoer.setActionName("Add Picture")
            node.position = point
            node.position.z += 0.05
            setParentOf(node, to: wall)
            return node
        } else {
            return nil
        }
    }
    
    /// A menu action to add a picture by getting a path from an open panel.
    func addPicture(sender: AnyObject?)
    {
        if let url = runOpenPanel() {
           self.addPicture(self.theNode!, path: url.path!, point: self.artSceneView.mouseClickLocation!)
        }
    }
    
    /// Replace a picture with a new one from `path`.
    func replacePicture(picture: SCNNode, path: String) {
        if  let size = picture.geometry as? SCNPlane,
            let _ = addPicture(picture.parentNode!, path: path, point: picture.position,
                size: CGSize(width: size.width, height: size.height)) {
            undoer.setActionName("Replace Picture")
            setParentOf(picture, to: nil)
        }
    }
    
    /// A menu action to replace a picture with a new one from a path from an open panel.
    func replacePicture(sender: AnyObject?)
    {
        if let url = runOpenPanel() {
            replacePicture(theNode!, path: url.path!)
        }
    }
    
    func deleteWall(sender: AnyObject?) {
        editMode = .None
        undoer.setActionName("Delete Wall")
        setParentOf(theNode!, to: nil)
       theNode = nil
    }
    
    /// A menu action to put the controller in `.Moving(.Wall)` mode.
    func editWallPosition(sender: AnyObject?) {
        editMode = .Moving(.Wall)
        let (_, location, _, distance) = wallInfo(theNode!, camera: artSceneView.camera())
        status = "Wall Position: \(location); Distance: \(distance!)"
    }
    
    /// A menu action to put the controller in `.Resizing(.Wall)` mode.
    func editWallSize(sender: AnyObject?)
    {
        editMode = .Resizing(.Wall, .None)
        let (size, _, _, _) = wallInfo(theNode!)
        status = "Wall Size: \(size)"
    }
    
    /// A menu action to put the controller in `.Resizing(.Picture)` mode.
    func editFrameSize(sender: AnyObject?)
    {
        editMode = .Resizing(.Picture, .None)
        if let theNode = theNode {
            let (size, _, _) = pictureInfo(theNode)
            status = "Picture: \(size)"
        } else {
            status = ""
        }
    }
    
    /// A menu action to put the controller in `.Moving(.Picture)` mode.
    @IBAction func editFramePosition(sender: AnyObject?)
    {
        editMode = .Moving(.Picture)
        if let theNode = theNode {
            let (_, location, _) = pictureInfo(theNode)
            status = "Picture Location: \(location)"
        } else {
            status = ""
        }
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setPosition1(args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let v = args["position"] as! [CGFloat]
        let vec = SCNVector3(x: v[0], y: v[1], z: v[2])
        setPosition(node, position: vec)
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setPivot1(args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let angle = args["angle"] as! CGFloat
        setPivot(node, angle: angle)
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setNodeSize1(args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let v = args["size"] as! [CGFloat]
        setNodeSize(node, size: CGSize(width: v[0], height: v[1]))
    }
    
    /// Required by the `Undo` protocol. Unpacks the argument and calls the set method.
    func setParentOf1(args: [String: AnyObject])
    {
        let node = args["node"] as! SCNNode
        let parent = args["parent"] as? SCNNode
        setParentOf(node, to: parent)
    }
    
// MARK: Edit node position
    
    /// Edit the position of a picture or the selection using the arrow keys.
    func doFrameEditPosition(theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0
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
                    setPosition(picture, position: position)
                }
                let (_, location, _) = pictureInfo(theNode)
                status = "Picture Location: \(location)"
        }
    }
    
    /// Edit the position of a wall using the arrow keys. If the command key is down, then
    /// use the left and right arrow keys to rotate the wall. If the shift key is down,
    /// use smaller deltas.
    func doWallEditPosition (theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 0.1 : 1.0
                let rotation: CGFloat = (shift ? 1 : 10) / r2d
                let keyChar = Int(keyString[keyString.startIndex])
                SCNTransaction.setAnimationDuration(0.5)
                if modifiers.contains(.CommandKeyMask) {
                    var angle = theNode.eulerAngles.y
                    switch keyChar {
                    case NSLeftArrowFunctionKey:
                        SCNTransaction.setAnimationDuration(0.2)
                        angle += rotation
                    case NSRightArrowFunctionKey:
                        SCNTransaction.setAnimationDuration(0.2)
                        angle -= rotation
                    default:
                        super.keyDown(theEvent)
                    }
                    setPivot(theNode, angle: angle)
                } else {
                    var position = theNode.position
                    switch keyChar {
                    case NSUpArrowFunctionKey:
                        position.z -= jump
                    case NSDownArrowFunctionKey:
                        position.z += jump
                    case NSLeftArrowFunctionKey:
                        position.x -= jump
                    case NSRightArrowFunctionKey:
                        position.x += jump
                    default: break
                    }
                    setPosition(theNode, position: position)
                }
                let (_, location, _, distance) = wallInfo(theNode, camera: artSceneView.camera())
                status = "Wall Position: \(location); Distance: \(distance!)"
        }
    }
    
    /// Edit the size of the frame using the arrow keys. If the shift key is down, use smaller deltas.
    func doFrameEditSize(theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode,
            let plane = theNode.geometry as! SCNPlane? {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0
                let keyChar = Int(keyString[keyString.startIndex])
                var size = CGSize(width: plane.width, height: plane.height)
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
                setNodeSize(theNode, size: size)
                let (newsize, _, _) = pictureInfo(theNode)
                status = "Picture Size: \(newsize)"
        }
    }
    
    /// Edit the size fo a wall using the arrow keys. If the shift key is down, use smaller deltas.
    /// Ensure that the wall encloses all the pictures.
    func doWallEditSize(theEvent: NSEvent)
    {
        if let theNode = theNode,
            let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let plane = theNode.geometry as! SCNPlane? {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 1 / 12 : 0.5
                let keyChar = Int(keyString[keyString.startIndex])
                var size = CGSize(width: plane.width, height: plane.height)
                var dx: CGFloat = 0.0
                var dy: CGFloat = 0.0
                switch keyChar {
                case NSUpArrowFunctionKey:
                    dy = jump
                 case NSDownArrowFunctionKey:
                    let newHeight = plane.height - jump
                    if wallContainsPictures(theNode, withNewSize: CGSize(width: plane.width, height: newHeight)) {
                        dy = -jump
                    }
                case NSRightArrowFunctionKey:
                    dx = jump
                case NSLeftArrowFunctionKey:
                    let newWidth = plane.width - jump
                    if wallContainsPictures(theNode, withNewSize: CGSize(width: newWidth, height: plane.height)) {
                        dx = -jump
                    }
                default:
                    super.keyDown(theEvent)
                }
                size.width += dx
                size.height += dy
                setNodeSize(theNode, size: size)
                let info = wallInfo(theNode)
                status = "Wall Size: \(info.size)"
        }
    }

//    func moveSelection(charCode: Int, shift: Bool) {
//        let selection = artSceneView.selection
//        let jump: CGFloat = shift ? 0.25 / 12.0 : 1.0 / 12.0
//        for node in selection {
//            var position = node.position
//            switch charCode {
//            case NSLeftArrowFunctionKey:
//                position.x -= jump
//            case NSRightArrowFunctionKey:
//                position.x += jump
//            case NSUpArrowFunctionKey:
//                position.y += jump
//            case NSDownArrowFunctionKey:
//                position.y -= jump
//            default:
//                break
//            }
//            setPosition(node, position: position)
//        }
//        if let node = artSceneView.masterNode,
//            let plane = node.parentNode?.geometry as? SCNPlane {
//            status = "{ \(convertToFeetAndInches(node.position.x + plane.width / 2)), "
//                + "\(convertToFeetAndInches(node.position.y + plane.height / 2)) }"
//        }
//    }
    
    func updateCameraStatus() {
        let camera = artSceneView.camera()
        let x = convertToFeetAndInches(camera.position.x)
        let y = convertToFeetAndInches(camera.position.y)
        let z = convertToFeetAndInches(camera.position.z)
        let rot = camera.eulerAngles.y * r2d
        let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
        status = "Camera: " + "[\(x), \(y), \(z)] \(rot1)"
    }
    
    /// Change the location and rotation of the camera with the arrow keys. The rotation
    /// is changed if the command key is down.
    func doCameraEdit(theEvent: NSEvent) {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16 {
            let modifiers = theEvent.modifierFlags
            let charCode = Int(keyString[keyString.startIndex])
//            if modifiers.contains(.AlternateKeyMask) {
//                moveSelection(charCode, shift: modifiers.contains(.ShiftKeyMask))
//                return
//            }
            let shift = modifiers.contains(.ShiftKeyMask)
            let jump: CGFloat = shift ? 0.1 : 1.0
            let rotation: CGFloat = (shift ? 1 : 10) / r2d
            let cameraNode = artSceneView.camera()
            SCNTransaction.setAnimationDuration(0.5)
            if modifiers.contains(.CommandKeyMask) {
                switch charCode {
                case NSLeftArrowFunctionKey:
                    cameraNode.eulerAngles.y += rotation
                case NSRightArrowFunctionKey:
                     cameraNode.eulerAngles.y -= rotation
                case NSUpArrowFunctionKey:
                     cameraNode.position.y += jump
                case NSDownArrowFunctionKey:
                     cameraNode.position.y -= jump
                default:
                    super.keyDown(theEvent)
                }
                
            } else {
                let angle = cameraNode.eulerAngles.y
                var v = SCNVector3(x: sin(angle) * jump, y: 0.0, z: cos(angle) * jump)
                let u = v × SCNVector3(0, 1, 0)
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
            }
            updateCameraStatus()
        }
    }
    
    /// Dispatch the key down event on `editMode`.
    override func keyDown(theEvent: NSEvent)
    {
        if theEvent.modifierFlags.contains(.NumericPadKeyMask) {
            if case EditMode.None = editMode {
                doCameraEdit(theEvent)
            } else {
                guard let theNode = theNode else {
                    status = "No object!"
                    return
                }
                if !preparedForUndo {
                    prepareForUndo(theNode)
                    preparedForUndo = true
                }
                switch editMode {
                case .Moving(.Wall):
                    doWallEditPosition(theEvent)
                case .Resizing(.Wall, _):
                    doWallEditSize(theEvent)
                case .Resizing(.Picture, _):
                    doFrameEditSize(theEvent)
                case .Moving(.Picture):
                    doFrameEditPosition(theEvent)
                default: ()
                }
            }
            
        }
    }
    
    func menuBarClicked(info: AnyObject)
    {
        editMode = .None
    }
    
}