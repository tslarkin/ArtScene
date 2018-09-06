//
//  GameViewController.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit
import Quartz

/**
The view controller for an ArtSceneView. Handles moving, resizing, and rotating by
using the arrow keys.
*/
class ArtSceneViewController: NSViewController, Undo, SKSceneDelegate {
    
    @IBOutlet weak var artSceneView: ArtSceneView!
    var camera: SCNCamera {
        return artSceneView.camera().camera!
    }
    @IBOutlet weak var document: Document!
    /// The documents undo manager
    var undoer:UndoManager {
        get { return document.undoManager! }
    }
    
    /// The status bar is a text field at the top of the window.
    @IBOutlet weak var statusBar: NSTextField!
    
    /// `true` if the controller is prepared for undo. The controller opens an undo grouping
    /// when key based editing begins. A change in `editMode` triggers an end to that grouping.
//    var preparedForUndo: Bool = false
    
    var editMode = EditMode.none {
        willSet(newMode) {
            if case EditMode.none = newMode {
                if undoer.groupingLevel == 1 {
                    undoer.endUndoGrouping()
                }
            }
        }
    }
    
    var defaultFrameSize: CGSize = CGSize(width: 2, height: 2)
    /// The target of key-based editing, either a picture or a wall.
    var defaultWallSize = CGSize(width: 20, height: 10)
    /// The user selected wall color, which is the same for all walls
    var wallColor: NSColor = NSColor.white {
        didSet {
            let walls = scene.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall" })
            for wall in walls {
                wall.geometry?.firstMaterial?.diffuse.contents = wallColor
            }
            
        }
    }
    
    var hudUpdate: SKNode?
    
    var cameraHidden: Bool = false
    
    @objc func setColorOfWalls(_ sender: AnyObject?) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            self.wallColor = color
        }
    }
    
    @IBAction func pickWallColor(_ sender: AnyObject?)
    {
        let picker = NSColorPanel.shared
        picker.setTarget(self)
        picker.setAction(#selector(ArtSceneViewController.setColorOfWalls(_:)))
        picker.color = wallColor
        picker.isContinuous = true
        picker.orderFront(nil)
    }
    
    var theNode: SCNNode? = nil

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
    var selection: Array<SCNNode> {
        get { return artSceneView.selection }
        set { artSceneView.selection = newValue }
    }
    
    var wallsLocked = false
    
    var scene:SCNScene {
        return artSceneView.scene!
    }
    
    func makeWall(at: SCNVector3)->SCNNode {
        let wall = SCNPlane(width: defaultWallSize.width, height: defaultWallSize.height)
        let paint = SCNMaterial()
        paint.diffuse.contents = wallColor
        paint.isDoubleSided = true
        wall.materials = [paint]
        let wallNode = SCNNode(geometry: wall)
        wallNode.name = "Wall"
        wallNode.position = at
        wallNode.position.y = defaultWallSize.height / 2.0
        wallNode.castsShadow = true
        
        let font = NSFont(name: "Lucida Grande", size: 0.75)!
        let attributes = [NSAttributedStringKey.font: font]
        let string = NSAttributedString(string: "Back", attributes: attributes)
        let size = string.size()
        let text = SCNText(string: string, extrusionDepth: 0.0)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.black
        text.materials = [material]
        let back = SCNNode(geometry: text)
        back.position = SCNVector3Make(size.width / 2.0, -size.height / 2.0, -0.1)
        back.yRotation = .pi
        wallNode.yRotation = artSceneView.camera().yRotation
        wallNode.addChildNode(back)
        return wallNode
    }
    
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
        
//        NotificationCenter.default.addObserver(self, selector: #selector(ArtSceneViewController.undoStarted(_:)), name: NSNotification.Name.NSUndoManagerDidOpenUndoGroup, object: nil)
    }
    
//    @objc func undoStarted(_ note: NSNotification)
//    {
//        Swift.print("Undo Started")
//    }
    
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
            undoer.beginUndoGrouping()
            undoer.setActionName("Change Picture Size")
            let node = theNode!
            let size = theNode!.size()!
            changePictureSize(node, from: size, to: defaultFrameSize)
            undoer.endUndoGrouping()
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
    @discardableResult func addPicture(_ wall: SCNNode,
                                       path: String,
                                       point: SCNVector3,
                                       size: CGSize = CGSize.zero) -> SCNNode? {
        if let node = makePicture(path, size: size) {
            undoer.beginUndoGrouping()
            undoer.setActionName("Add Picture")
            node.position = point
            node.position.z += 0.05
            changeParent(node, from: nil, to: wall)
            undoer.endUndoGrouping()
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
        undoer.beginUndoGrouping()
        undoer.setActionName("Replace Picture")
        undoer.registerUndo(withTarget: self, handler: { $0.replacePicture(with, with: picture)})
        picture.parent!.replaceChildNode(picture, with: with)
        undoer.endUndoGrouping()
    }
    
    /// Replace a picture with a new one from `path`.
    func replacePicture(_ picture: SCNNode, path: String) {
        let size = picture.size()!
        if let newPicture = makePicture(path, size: size) {
            newPicture.position = picture.position
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
        undoer.beginUndoGrouping()
        undoer.setActionName("Delete Wall")
        changeParent(theNode!, from: theNode!.parent!, to: nil)
        undoer.endUndoGrouping()
        theNode = nil
    }
    
    @IBAction func addWall(_ sender: AnyObject?) {
        undoer.beginUndoGrouping()
        undoer.setActionName("Add Wall")
        let wallNode = makeWall(at: artSceneView.mouseClickLocation!)
        changeParent(wallNode, from: nil, to: scene.rootNode)
        undoer.endUndoGrouping()
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
            let (size, _, _, _) = pictureInfo(theNode)
            status = "Picture: \(size)"
        } else {
            status = ""
        }
    }
    
    @objc func editImageSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Image, .none)
        let (size, _) = imageInfo(theNode!)
        status = "Image: \(size)"
     }
    
    /// A menu action to put the controller in `.Moving(.Picture)` mode.
    @IBAction func editFramePosition(_ sender: AnyObject?)
    {
        editMode = .moving(.Picture)
        if let theNode = theNode {
            let (_, location, _, _) = pictureInfo(theNode)
            status = "Location: \(location)"
        } else {
            status = ""
        }
    }
    
    @objc func rotateWallCW()
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Rotate Wall CW")
        changePivot(theNode!, delta: -.pi / 2.0)
        undoer.endUndoGrouping()
        artSceneView.getInfo(theNode!)
    }
    
    @objc func rotateWallCCW()
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Rotate Wall CCW")
        changePivot(theNode!, delta: .pi / 2.0)
        undoer.endUndoGrouping()
        artSceneView.getInfo(theNode!)
   }

    func updateCameraStatus() {
        if (cameraHidden) { return }
        let camera = artSceneView.camera()
        let x = convertToFeetAndInches(camera.position.x)
        let y = convertToFeetAndInches(camera.position.y)
        let z = convertToFeetAndInches(camera.position.z)
        let rotY = (camera.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot1 = String(format: "%.0f°", rotY < 0 ? rotY + 360 : rotY)
        let rotX = (camera.eulerAngles.x * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot2 = String(format: "%.0f°", rotX < 0 ? rotX + 360 : rotX)
        let fov: Int
        if #available(OSX 10.13, *) {
            fov = Int(camera.camera!.fieldOfView)
        } else {
            fov = Int(camera.camera!.xFov)
        }
        
        let hudDictionary: [(String, String)] = [("x", x), ("y", y), ("z", z), ("y°", rot1), ("x°", rot2), ("fov", String(format: "%2d", fov))]
        hudUpdate = makeDisplay(title: "Camera", items: hudDictionary, width: 175)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
    }
    
    @objc func menuBarClicked(_ info: AnyObject)
    {
//        editMode = .none
    }
    
   func makeDisplay(title aTitle: String,
                                       items: [(String, String)],
                                       width: CGFloat? = nil)->SKNode
    {
        
        func makeTextNode(text: String,
                          position: CGPoint,
                          fontSize: CGFloat,
                          alignment: SKLabelHorizontalAlignmentMode)->SKLabelNode
        {
            let node = SKLabelNode(text: text)
            node.fontName = "Lucida Grande"
            node.fontSize = fontSize
            node.fontColor = NSColor.white
            node.position = position
            node.horizontalAlignmentMode = alignment
            return node
        }
        
        var maxLabelSize: CGFloat = 0.0
        var rowDataSizes: Dictionary<String, CGFloat> = [:]
        let fontSize: CGFloat = 24
        let font = NSFont(name: "LucidaGrande", size: fontSize)
        let attributes: [NSAttributedStringKey: AnyObject] = [.font: font!]
        for(key, value) in items {
            let keysize = (key as NSString).size(withAttributes: attributes)
            let ksize: CGFloat = keysize.width
            maxLabelSize = max(ksize, maxLabelSize)
            let vsize: CGFloat = (value as NSString).size(withAttributes: attributes).width
            rowDataSizes[value] = vsize
        }
        let maxDataSize: CGFloat = rowDataSizes.values.reduce(0.0, { max($0, $1) })
        let colsep: CGFloat = 20
        let lineHeight: CGFloat = 29
        let margin: CGFloat = 10
        let flexibleWidth = maxDataSize + maxLabelSize + colsep + margin * 2.0
        var title = aTitle
        let titleWidth = width != nil ? width! - 2 * margin : flexibleWidth
        title = title.truncate(maxWidth: titleWidth, attributes: attributes)
        let displayWidth = width ?? flexibleWidth
        let displaySize = CGSize(width: displayWidth, height: lineHeight * (CGFloat(items.count + 2)))
        let displayRect = CGRect(origin: CGPoint.zero, size: displaySize)
        let path = CGPath(roundedRect: displayRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let display = SKShapeNode(path: path, centered: true)
        display.fillColor = NSColor.gray
        let color = NSColor(calibratedWhite: 0.05, alpha: 0.98)
        display.fillColor = color
        let size = artSceneView.frame.size
        display.position = CGPoint(x: size.width / 3.0 - displaySize.width / 2.0, y: size.height / 2.0)
        display.name = "HUD Display"
        
        var y: CGFloat = CGFloat(items.count) * lineHeight / 2.0
        let titleNode = makeTextNode(text: title,
                                     position: CGPoint(x: 0.0, y: y),
                                     fontSize: fontSize, alignment: .center)
        titleNode.fontColor = NSColor.systemYellow
        display.addChild(titleNode)
        y -= lineHeight + 8.0
        for (key, value) in items {
            let keyNode = makeTextNode(text: key,
                                       position: CGPoint(x: -displaySize.width / 2.0 + margin, y: y),
                                       fontSize: fontSize, alignment: .left)
            display.addChild(keyNode)
            let dataNode = makeTextNode(text: value,
                                        position: CGPoint(x: displaySize.width / 2.0 - margin, y: y),
                                        fontSize: fontSize, alignment: .right)
            display.addChild(dataNode)
            y -= lineHeight
        }
        return display
    }
    
    func update(_ currentTime: TimeInterval, for scene: SKScene)
    {
        if let update = hudUpdate {
            for child in scene.children {
                child.removeAllActions()
            }
            scene.removeAllChildren()
            scene.addChild(update)
        }
        hudUpdate = nil
    }

    
}
