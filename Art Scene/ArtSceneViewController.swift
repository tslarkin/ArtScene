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
    
    var editMode = EditMode.none {
        willSet(newMode) {
            if case EditMode.none = newMode, preparedForUndo {
                registerUndos()
                undoer.endUndoGrouping()
                preparedForUndo = false
            }
        }
    }
    
    var defaultFrameSize: CGSize = CGSize(width: 2, height: 2)
    /// The target of key-based editing, either a picture or a wall.
    var defaultWallSize = CGSize(width: 20, height: 8)
    var theNode: SCNNode? = nil
    var undoer:UndoManager {
        get { return (document?.undoManager)! }
    }

    @objc dynamic var status: String = ""
    
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
    
    var wallsLocked = false
    var saved: Any = ""
    
    @objc func lockWalls()
    {
        if (artSceneView.scene?.rootNode.childNode(withName: "Lock", recursively: false)) != nil
        {
            return
        }
        wallsLocked = true
        let lock = SCNNode()
        lock.isHidden = true
        lock.name = "Lock"
        artSceneView.scene?.rootNode.addChildNode(lock)
    }
    
    func unlockWalls()
    {
        if let lock = artSceneView.scene?.rootNode.childNode(withName: "Lock", recursively: false)
        {
            lock.removeFromParentNode()
        }
        wallsLocked = false
    }
    
    @objc func unlockWallsWithConfirmation()
    {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to unlock the walls?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertSecondButtonReturn {
            unlockWalls()
        }
    }
    
    @IBAction func hideStatus(_ sender: AnyObject) {
        status = ""
        artSceneView.editMode = .none
    }
    
    override func awakeFromNib(){
        Bundle.main.loadNibNamed(("ActionMenu" as NSString) as NSNib.Name, owner: artSceneView, topLevelObjects: nil)
        
        // create a new scene
        
        // allows the user to manipulate the camera
        self.artSceneView!.allowsCameraControl = false
        
        // show statistics such as fps and timing information
        self.artSceneView!.showsStatistics = false
        
        // configure the view
        self.artSceneView!.backgroundColor = NSColor.black
        
        let window = artSceneView!.window!
        window.acceptsMouseMovedEvents = true;
        window.makeFirstResponder(artSceneView)
        
        // Clicking in the menu bar ends the undo group.
        NotificationCenter.default.addObserver(self, selector: #selector(ArtSceneViewController.menuBarClicked(_:)),
                                               name: NSMenu.didBeginTrackingNotification, object: NSApp.mainMenu)
    }
    
    func doChangeImageSize(_ node: SCNNode, from: CGSize, to: CGSize)
    {
        changeImageSize(node, from: from, to: to)
    }
    
    func doChangePictureSize(_ node: SCNNode, from: CGSize, to: CGSize)
    {
        changePictureSize(node, from: from, to: to)
    }
    
    /// A menu action to reframe a picture to one of the standard sizes.
    @objc func reframePicture(_ sender: AnyObject?)
    {
        if let sender = sender as? NSMenuItem {
            let title = sender.title
            defaultFrameSize = frameSizes[title]!
            defaultFrameSize.width /= 12
            defaultFrameSize.height /= 12
            reframePictureWithSize(theNode!, newsize: defaultFrameSize)
        }
    }
    
    /// Hide the frame
    func _hideFrame(_ node: SCNNode) {
        if let child = node.childNode(withName: "Frame", recursively: false) {
            child.isHidden = true
        }
        if let child = node.childNode(withName: "Matt", recursively: false) {
            child.isHidden = true
        }
    }
    
    @objc func hideFrame(_ sender: AnyObject?) {
        _hideFrame(theNode!)
    }
    
    /// Show the frame
    @objc func showFrame(_ sender: AnyObject?) {
        if let child = theNode?.childNode(withName: "Frame", recursively: false) {
            child.isHidden = false
        }
        if let child = theNode?.childNode(withName: "Matt", recursively: false) {
            child.isHidden = false
        }
    }
    
    /// Add a picture based on an image from the path at a given location.
    @discardableResult func addPicture(_ wall: SCNNode, path: String, point: SCNVector3, size: CGSize = CGSize.zero) -> SCNNode? {
        if let node = makePicture(path, size: size) {
            undoer.setActionName("Add Picture")
            node.position = point
            node.position.z += 0.05
            changeParent(node, from: nil, to: wall)
            return node
        } else {
            return nil
        }
    }
    
    /// A menu action to add a picture by getting a path from an open panel.
    @objc func addPicture(_ sender: AnyObject?)
    {
        if let url = runOpenPanel() {
            self.addPicture(self.theNode!, path: url.path, point: self.artSceneView.mouseClickLocation!)
        }
    }
    
    func replacePicture(_ picture: SCNNode, with: SCNNode)
    {
        undoer.setActionName("Replace Picture")
        let undo: ArtSceneViewController = undoer.prepare(withInvocationTarget: self) as! ArtSceneViewController
        undo.replacePicture(with, with: picture)
        picture.parent!.replaceChildNode(picture, with: with)
    }
    
    /// Replace a picture with a new one from `path`.
    func replacePicture(_ picture: SCNNode, path: String) {
        let size = picture.size()!
        if let newPicture = makePicture(path, size: size) {
            replacePicture(picture, with: newPicture)
        }
    }
    
    /// A menu action to replace a picture with a new one from a path from an open panel.
    @objc func replacePicture(_ sender: AnyObject?)
    {
        if let url = runOpenPanel() {
            
            replacePicture(theNode!, path: url.path)
        }
    }
    
    @objc func deleteWall(_ sender: AnyObject?) {
        editMode = .none
        undoer.setActionName("Delete Wall")
        changeParent(theNode!, from: theNode!.parent!, to: nil)
       theNode = nil
    }
    
    func registerUndos()
    {
        guard let mouseNode = theNode else { return }
        switch editMode {
        case .resizing(.Picture, _):
            changePictureSize(mouseNode, from: saved as! CGSize, to: mouseNode.size()!)
        case .resizing(.Image, _):
            changeImageSize(mouseNode, from: saved as! CGSize, to: mouseNode.childNode(withName: "Image", recursively: false)!.size()!)
        case .resizing(.Wall, _):
            let (oldSize, oldPosition) = saved as! (CGSize, SCNVector3)
            changeSize(mouseNode, from: oldSize, to: mouseNode.size()!)
            changePosition(mouseNode, from: oldPosition, to: mouseNode.position)
        case .moving(.Picture):
            for (node, oldPosition, parent) in saved as! [(SCNNode, SCNVector3, SCNNode)] {
                let position = snapToGrid(node.position)
                changePosition(node, from: oldPosition, to: position)
                changeParent(node, from: parent, to: node.parent!)
            }
        case .moving(.Wall):
            if !wallsLocked {
                let position = snapToGrid(mouseNode.position)
                changePosition(mouseNode, from: saved as! SCNVector3, to: position)
            }
        default:
            ()
        }
    }
    
    /// A menu action to put the controller in `.Moving(.Wall)` mode.
    @objc func editWallPosition(_ sender: AnyObject?) {
        editMode = .moving(.Wall)
        let (_, location, _, distance) = wallInfo(theNode!, camera: artSceneView.camera())
        status = "Wall Position: \(location); Distance: \(distance!)"
    }
    
    /// A menu action to put the controller in `.Resizing(.Wall)` mode.
    @objc func editWallSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Wall, .none)
        let (size, _, _, _) = wallInfo(theNode!)
        status = "Wall Size: \(size)"
    }
    
    /// A menu action to put the controller in `.Resizing(.Picture)` mode.
    @objc func editFrameSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Picture, .none)
        if let theNode = theNode {
            let (size, _) = pictureInfo(theNode)
            status = "Picture: \(size)"
        } else {
            status = ""
        }
    }
    
    @objc func editImageSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Image, .none)
        if let theNode = theNode {
            let (size, name) = imageInfo(theNode)
            status = "\(name): \(size)"
        } else {
            status = ""
        }
    }
    
    /// A menu action to put the controller in `.Moving(.Picture)` mode.
    @IBAction func editFramePosition(_ sender: AnyObject?)
    {
        editMode = .moving(.Picture)
        if let theNode = theNode {
            let (_, location) = pictureInfo(theNode)
            status = "Picture Location: \(location)"
        } else {
            status = ""
        }
    }
    
// MARK: Edit node position
    
    /// Edit the position of a picture or the selection using the arrow keys.
    func doFrameEditPosition(_ theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.shift)
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
                    picture.position = position
                }
                let (_, location) = pictureInfo(theNode)
                status = "Picture Location: \(location)"
        }
    }
    
    /// Edit the position of a wall using the arrow keys. If the command key is down, then
    /// use the left and right arrow keys to rotate the wall. If the shift key is down,
    /// use smaller deltas.
    func doWallEditPosition (_ theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.shift)
                let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 6.0
                let rotation: CGFloat = 5.01 / r2d
                let keyChar = Int(keyString[keyString.startIndex])
                SCNTransaction.animationDuration = 0.5
                if modifiers.contains(.command) {
                    var angle = theNode.yRotation()
                    switch keyChar {
                    case NSLeftArrowFunctionKey:
                        SCNTransaction.animationDuration = 0.2
                        angle += rotation
                    case NSRightArrowFunctionKey:
                        SCNTransaction.animationDuration = 0.2
                        angle -= rotation
                    default:
                        super.keyDown(with: theEvent)
                    }
                    theNode.setYRotation(angle)
                } else {
                    var dz: CGFloat = 0.0
                    var dx: CGFloat = 0.0
                    switch keyChar {
                    case NSUpArrowFunctionKey:
                        dz = -jump
                    case NSDownArrowFunctionKey:
                        dz = jump
                    case NSLeftArrowFunctionKey:
                        dx = jump
                    case NSRightArrowFunctionKey:
                        dx = -jump
                    default: break
                    }
                    let translate = simd_make_float3(Float(-dx), 0.0, Float(dz))
                    theNode.simdLocalTranslate(by: translate)
                }
                let (_, location, rot, distance) = wallInfo(theNode, camera: artSceneView.camera())
            status = "Wall Position: \(location); Distance: \(distance!); Rotation: \(rot)"
        }
    }
    
    /// Edit the size of the frame using the arrow keys. If the shift key is down, use smaller deltas.
    func doFrameEditSize(_ theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
                var size = theNode.size()!
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.shift)
                let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0
                let keyChar = Int(keyString[keyString.startIndex])
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
                reframePictureWithSize(theNode, newsize: size)
                let (newsize, _) = pictureInfo(theNode)
                status = "Picture Size: \(newsize)"
        }
    }
    
    func doImageEditSize(_ theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let theNode = theNode {
            var size = theNode.childNode(withName: "Image", recursively: false)!.size()!
            let ratio = size.width / size.height
            let modifiers = theEvent.modifierFlags
            let shift = modifiers.contains(.shift)
            let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0
            let keyChar = Int(keyString[keyString.startIndex])
            switch keyChar {
            case NSUpArrowFunctionKey:
                size.height += jump
            case NSDownArrowFunctionKey:
                size.height -= jump
            default:
                return
            }
            size.width = size.height * ratio
            reframeImageWithSize(theNode, newsize: size)
            let (newsize, name) = imageInfo(theNode)
            status = "\(name): \(newsize)"
        }
    }
    
   /// Edit the size of a wall using the arrow keys. If the shift key is down, use smaller deltas.
    /// Ensure that the wall encloses all the pictures.
    func doWallEditSize(_ theEvent: NSEvent)
    {
        if let theNode = theNode,
            let keyString = theEvent.charactersIgnoringModifiers?.utf16 {
            let modifiers = theEvent.modifierFlags
            let shift = modifiers.contains(.shift)
            let jump: CGFloat = shift ? 1 / 48.0 : 0.25
            let keyChar = Int(keyString[keyString.startIndex])
            var size = theNode.size()!
            var newsize = size
            var dx: CGFloat = 0.0
            var dy: CGFloat = 0.0
            var doHeightCorrection = false
            var doPositionCorrection = false
            switch keyChar {
            case NSUpArrowFunctionKey:
                dy = jump
                doHeightCorrection = true
            case NSDownArrowFunctionKey:
                newsize.height -= jump
                if wallContainsPictures(theNode, withNewSize: newsize) {
                    dy = -jump
                }
            case NSRightArrowFunctionKey:
                dx = jump
                doPositionCorrection = true
            case NSLeftArrowFunctionKey:
                newsize.width -= jump
                if wallContainsPictures(theNode, withNewSize: newsize) {
                    doPositionCorrection = true
                    dx = -jump
                }
            default:
                super.keyDown(with: theEvent)
            }
            size.width += dx
            size.height += dy
            theNode.setSize(size)
            dx = doPositionCorrection ? dx / 2.0 : 0.0
            dy = doHeightCorrection ? dy / 2.0 : 0.0
            let factor: Float = modifiers.contains(.option) ? -1.0 : 1.0
            let translate = simd_make_float3(factor * Float(dx), 0.0, Float(-dy / 2.0))
            theNode.simdLocalTranslate(by: translate)
            defaultWallSize.height = size.height
            let info = wallInfo(theNode)
            status = "Wall Size: \(info.size)"
        }
    }
    
    @objc func rotateWallCW()
    {
        theNode?.eulerAngles.y -= .pi / 2.0
        artSceneView.getInfo(theNode!)
    }
    
    @objc func rotateWallCCW()
    {
        theNode?.eulerAngles.y += .pi / 2.0
        artSceneView.getInfo(theNode!)
   }

    func updateCameraStatus() {
        let camera = artSceneView.camera()
        let x = convertToFeetAndInches(camera.position.x)
        let y = convertToFeetAndInches(camera.position.y)
        let z = convertToFeetAndInches(camera.position.z)
        let rot = (camera.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
        let fov = Int(camera.camera!.fieldOfView)
        status = "Camera: " + "[\(x), \(y), \(z)] \(rot1) \(fov)"
    }
    
    /// Change the location and rotation of the camera with the arrow keys. The rotation
    /// is changed if the command key is down.
    func doCameraEdit(_ theEvent: NSEvent) {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16 {
            let modifiers = theEvent.modifierFlags
            let charCode = Int(keyString[keyString.startIndex])
            let shift = modifiers.contains(.shift)
            let jump: CGFloat = shift ? 0.1 : 1.0
            let rotation: CGFloat = (shift ? 1.0 : 5.0) / r2d
            let cameraNode = artSceneView.camera()
            let omniLight = artSceneView.omniLight()
            SCNTransaction.animationDuration = 0.5
            if modifiers.contains(.command) {
                switch charCode {
                case NSLeftArrowFunctionKey:
                    cameraNode.eulerAngles.y += rotation
                    omniLight.eulerAngles.y += rotation
                case NSRightArrowFunctionKey:
                    cameraNode.eulerAngles.y -= rotation
                    omniLight.eulerAngles.y -= rotation
                case NSUpArrowFunctionKey:
                    cameraNode.position.y += jump
                    omniLight.position.y += jump
                case NSDownArrowFunctionKey:
                    cameraNode.position.y -= jump
                    omniLight.position.y -= jump
                default:
                    super.keyDown(with: theEvent)
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
                omniLight.position = position
            }
            updateCameraStatus()
        }
    }
    
    @objc func undo(_ sender:AnyObject)
    {
        if preparedForUndo {
            editMode = .none
        }
        undoer.undo()
    }
    
    /// Dispatch the key down event on `editMode`.
    override func keyDown(with theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers {
            if keyString == "+" {
                
            } else if keyString == "-" {
                
            }
        }
        if theEvent.modifierFlags.contains(.numericPad) {
            if case EditMode.none = editMode {
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
                default: ()
                }
            }
            
        }
    }
    
    @objc func menuBarClicked(_ info: AnyObject)
    {
        editMode = .none
    }
    
}
