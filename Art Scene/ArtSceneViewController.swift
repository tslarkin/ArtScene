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
class ArtSceneViewController: NSViewController, Undo {
    
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
    
    var editMode = EditMode.none {
        willSet(newMode) {
            if case EditMode.none = newMode {
                if undoer.groupingLevel == 1 {
                    undoer.endUndoGrouping()
                }
                if editMode == .moving(.Picture) {
                    let wall = theNode!.parent!
                    for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid  && $0.name != nil}) {
                        unflattenPicture(node)
                    }
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
    var wantsCameraHelp: Bool = true
    var cameraHelp: SKNode!
    var frameSizeChanged: Bool = false
    
    @objc func setColorOfWalls(_ sender: AnyObject?) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            self.wallColor = color
        }
    }
    
    @IBAction func pickBoxColor(_ sender: AnyObject?)
    {
        let picker = NSColorPanel.shared
        picker.setTarget(self)
        picker.setAction(#selector(ArtSceneViewController.setBoxColor(_:)))
        let box = theNode!.geometry as! SCNBox
        let color = box.firstMaterial?.diffuse.contents as! NSColor
        picker.color = color
        picker.isContinuous = true
        picker.orderFront(nil)
    }
    
    @objc func setBoxColor(_ sender: AnyObject) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            let box = theNode!.geometry as! SCNBox
            let materials = box.materials
            for material in materials {
                material.diffuse.contents = color
            }
        }
    }
    
    @IBAction func pickChairColor(_ sender: AnyObject?)
    {
        let picker = NSColorPanel.shared
        picker.setTarget(self)
        picker.setAction(#selector(ArtSceneViewController.setChairColor(_:)))
        let chair = theNode!.childNode(withName: "Wooden_Chair", recursively: false)!
        let color = chair.geometry!.firstMaterial?.diffuse.contents as! NSColor
        picker.color = color
        picker.isContinuous = true
        picker.orderFront(nil)
    }
    
    @objc func setChairColor(_ sender: AnyObject) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            let chair = theNode!.childNode(withName: "Wooden_Chair", recursively: false)!
            chair.geometry!.firstMaterial?.diffuse.contents = color
        }
    }

    @IBAction func pickTableColor(_ sender: AnyObject?)
    {
        let picker = NSColorPanel.shared
        picker.setTarget(self)
        picker.setAction(#selector(ArtSceneViewController.setTableColor(_:)))
        let top = theNode!.childNode(withName: "Top", recursively: false)!
        let color = top.geometry!.firstMaterial?.diffuse.contents as! NSColor
        picker.color = color
        picker.isContinuous = true
        picker.orderFront(nil)
    }
    
    @objc func setTableColor(_ sender: AnyObject) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            var parts = [theNode!.childNode(withName: "Top", recursively: false)!,
                         theNode!.childNode(withName: "Under", recursively: false)!]
            parts.append(contentsOf: theNode!.childNode(withName: "Legs", recursively: false)!.childNodes)
            for part in parts {
                part.geometry!.firstMaterial?.diffuse.contents = color
            }
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
    
    func makeBox(at: SCNVector3)->SCNNode {
        let box = SCNBox(width: 3.0, height: 3.0, length: 6.0, chamferRadius: 0.0)
        let paint = SCNMaterial()
        paint.diffuse.contents = NSColor.lightGray
        paint.isDoubleSided = false
        box.materials = [paint]
        let boxNode = SCNNode(geometry: box)
        boxNode.name = "Box"
        boxNode.position = at
        boxNode.position.y = 1.5
        boxNode.castsShadow = true

        var materials:[SCNMaterial] = []
        for _ in 0..<6 {
            let material = SCNMaterial()
            material.diffuse.contents = NSColor.lightGray
            materials.append(material)
        }
        boxNode.geometry?.materials = materials
        
        return boxNode
    }

    
    @IBAction func hideStatus(_ sender: AnyObject) {
        status = ""
        artSceneView.editMode = .none
    }
    
    override func awakeFromNib(){
        Bundle.main.loadNibNamed(("ActionMenu" as NSString) as NSNib.Name, owner: artSceneView, topLevelObjects: nil)
        
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["cameraHidden": false, "wantsCameraHelp": true])
        cameraHidden = defaults.bool(forKey: "cameraHidden")
        wantsCameraHelp = defaults.bool(forKey: "wantsCameraHelp")
        
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
        
        cameraHelp = makeCameraHelp()
        
        // Clicking in the menu bar ends the undo group.
        NotificationCenter.default.addObserver(self, selector: #selector(ArtSceneViewController.menuBarClicked(_:)),
                                               name: NSMenu.didBeginTrackingNotification, object: NSApp.mainMenu)
        
//        NotificationCenter.default.addObserver(self, selector: #selector(ArtSceneViewController.undoStarted(_:)), name: NSNotification.Name.NSUndoManagerDidOpenUndoGroup, object: nil)
    }
    
//    @objc func undoStarted(_ note: NSNotification)
//    {
//        Swift.print("Undo Started")
//    }
    
    // MARK: - Spotlights
    @IBAction func addSpotlight(_ sender: AnyObject)
    {
        if let node = theNode, nodeType(node) == .Picture, node.childNode(withName: "Spotlight", recursively: false) == nil {
            let wall = node.parent!
            let wallHeight = wall.size()!.height
//            let pictureHeight = node.position.y + wall.position.y
            let d1: CGFloat = 3.0 // distance between wall and light
            let d2: CGFloat = wallHeight / 2.0 - node.position.y - node.size()!.height / 4.0
//            let d3 = sqrt(d1 * d1 + d2 * d2) // direct distance between spot and center of picture
            let angle = atan(-d2 / d1)
            
            let light = SCNLight()
            light.type = .spot
//            light.attenuationStartDistance = 2.0
//            light.attenuationEndDistance = d3
            light.attenuationFalloffExponent = 2.0
            light.spotInnerAngle = 1
            light.spotOuterAngle = 40
            light.castsShadow = true
            light.color = NSColor(white: artSceneView.spotlightIntensity, alpha: 1.0)
//            light.shadowMode = .deferred
            
            let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = NSColor.red
            
            let lightNode = SCNNode()
            lightNode.name = "Spotlight"
            lightNode.position.y = wallHeight / 2.0 - node.position.y
            lightNode.position.z = d1
            lightNode.yRotation = 0.0
            lightNode.eulerAngles.x = angle
            lightNode.light = light
            node.addChildNode(lightNode)
            
        }
    }
    
    @IBAction func removeSpotlight(_ sender: AnyObject)
    {
        if let node = theNode, nodeType(node) == .Picture, let spot = node.childNode(withName: "Spotlight", recursively: false) {
            spot.removeFromParentNode()
        }

    }
    
    // MARK: - Pictures
    func doChangeImageSize(_ node: SCNNode, from: CGSize, to: CGSize)
    {
        changeImageSize(node, to: to)
    }
    
    func doChangePictureSize(_ node: SCNNode, to: CGSize)
    {
        changePictureSize(node, to: to)
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
            changePictureSize(node, to: defaultFrameSize)
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
            changeParent(node, to: wall)
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
        changeParent(theNode!, to: nil)
        undoer.endUndoGrouping()
        theNode = nil
    }
    
    @IBAction func addWall(_ sender: AnyObject?) {
        undoer.beginUndoGrouping()
        undoer.setActionName("Add Wall")
        let wallNode = makeWall(at: artSceneView.mouseClickLocation!)
        changeParent(wallNode, to: scene.rootNode)
        undoer.endUndoGrouping()
    }

    @IBAction func addBox(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Add Box")
        let boxNode = makeBox(at: artSceneView.mouseClickLocation!)
        changeParent(boxNode, to: scene.rootNode)
        undoer.endUndoGrouping()
    }
    
    @IBAction func deleteBox(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Delete Box")
        changeParent(theNode!, to: nil)
        undoer.endUndoGrouping()
    }
    
    func makeChair(at point: SCNVector3)->SCNNode
    {
        let chairScene = SCNScene(named: "art.scnassets/pcraven_wood_chair3.dae")
        let chairNode = chairScene!.rootNode.childNode(withName: "Wooden_Chair", recursively: true)!
        chairNode.castsShadow = true
        let scale = chairNode.scale
        let bbox = chairNode.boundingBox
        let chairBox = SCNBox(width: (bbox.max.x - bbox.min.x + 2.0.inches) * scale.x,
                              height: (bbox.max.y - bbox.min.y) * scale.y,
                              length: (bbox.max.z - bbox.min.z) * scale.z,
                              chamferRadius: 0)
        let boxNode = SCNNode(geometry: chairBox)
        boxNode.position = SCNVector3Make(point.x, chairNode.position.y, point.z)
        boxNode.castsShadow = true
        chairNode.position = SCNVector3Make(0.0, 0.0, 0)
        boxNode.addChildNode(chairNode)
        boxNode.name = "Chair"
        var materials:[SCNMaterial] = []
        for _ in 0..<6 {
            let material = SCNMaterial()
            material.diffuse.contents = NSColor.clear
            if #available(OSX 13.0, *) {
                material.fillMode = .lines
            }
            materials.append(material)
        }
        boxNode.geometry?.materials = materials
        return boxNode
    }
    
    @IBAction func addChair(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Add Chair")
        let boxNode = makeChair(at: artSceneView.mouseClickLocation!)
//        boxNode.yRotation = -artSceneView.camera().yRotation - .pi / 2.0
        changeParent(boxNode, to: scene.rootNode)
        undoer.endUndoGrouping()
    }
    
    @IBAction func deleteChair(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Delete Chair")
        changeParent(theNode!, to: nil)
        undoer.endUndoGrouping()
    }
    
    func makeBoxMaterials(color: NSColor)->[SCNMaterial]
    {
        var materials:[SCNMaterial] = []
        for _ in 0..<6 {
            let material = SCNMaterial()
            material.diffuse.contents = color
            materials.append(material)
        }
        return materials
    }
    
    func makeTable(at point: SCNVector3)->SCNNode
    {
        let height: CGFloat = 2.5
        let length: CGFloat = 2.5
        let width: CGFloat = 4.0
        let topThickness: CGFloat = 2.0.inches
        let overhang: CGFloat = 4.0.inches
        let legThickness: CGFloat = 3.0.inches
        
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0.0)
        box.materials = makeBoxMaterials(color: NSColor.clear)
        let tableNode = SCNNode(geometry: box)
        tableNode.castsShadow = true
        tableNode.name = "Table"
        var p = point
        p.y = height / 2.0
        tableNode.position = p
        
        let color = NSColor(calibratedRed: 0.8392156863, green: 0.8392156863, blue: 0.8392156863, alpha: 1.0)
        let top = SCNBox(width: width, height: topThickness, length: length, chamferRadius: 0.0)
        top.firstMaterial?.diffuse.contents = color
        let topNode = SCNNode(geometry: top)
        topNode.castsShadow = true
        topNode.name = "TableTop"
        topNode.position = SCNVector3Make(0, height / 2.0 - topThickness / 2.0, 0)
        tableNode.addChildNode(topNode)
        
        let under = SCNBox(width: width - overhang * 2.0, height: topThickness, length: length - overhang * 2.0, chamferRadius: 0.0)
        under.firstMaterial?.diffuse.contents = color
        let underNode = SCNNode(geometry: under)
        underNode.castsShadow = true
        underNode.name = "Under"
        underNode.position.y = height / 2.0 - topThickness - topThickness / 2.0
        tableNode.addChildNode(underNode)
        
        let legs = SCNNode()
        legs.name = "Legs"
        legs.position.y = -topThickness / 2.0
        tableNode.addChildNode(legs)
        for x in [-1.0, 1.0] {
            for z in [-1.0, 1.0] {
                let leg = SCNCylinder(radius: legThickness / 2.0, height: height - topThickness)
                leg.firstMaterial?.diffuse.contents = color
                let legNode = SCNNode(geometry: leg)
                legNode.castsShadow = true
                legNode.name = "\(x),\(z)"
                legNode.position = SCNVector3Make(CGFloat(x) * (width / 2.0 - overhang), 0.0 , CGFloat(z) * (length / 2.0 - overhang))
                legs.addChildNode(legNode)
            }
        }
        
        
        return tableNode
    }
    
    func makeTableFromDAE(at point: CGPoint)->SCNNode
    {
        let scene = SCNScene(named: "art.scnassets/table.dae")
        let tableNode = scene!.rootNode.childNode(withName: "Table", recursively: true)!
        tableNode.name = "table"
        let top = tableNode.childNode(withName: "Top", recursively: true)!
        let topbb = top.boundingBox
        tableNode.position = SCNVector3Make(0.0, -topbb.max.y / 2.0, 0.0)
        let bbox = tableNode.boundingBox
        let tableHeight = bbox.max.y - bbox.min.y
        let tableBox = SCNBox(width: bbox.max.x - bbox.min.x, height: tableHeight, length: bbox.max.z - bbox.min.z, chamferRadius: 0)
        let boxNode = SCNNode(geometry: tableBox)
        boxNode.position = SCNVector3Make(point.x, tableHeight / 2.0, point.y)
        boxNode.addChildNode(tableNode)
        boxNode.name = "Table"
        var materials:[SCNMaterial] = []
        for _ in 0..<6 {
            let material = SCNMaterial()
            material.diffuse.contents = NSColor.clear
//            if #available(OSX 10.13, *) {
//                material.fillMode = .lines
//                material.diffuse.contents = NSColor.red
//            }
            materials.append(material)
        }
        boxNode.geometry?.materials = materials
        return boxNode
    }
    
    @IBAction func addTable(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Add Table")
        let boxNode = makeTable(at: artSceneView.mouseClickLocation!)
        boxNode.yRotation = -artSceneView.camera().yRotation - .pi / 2.0
        changeParent(boxNode, to: scene.rootNode)
        undoer.endUndoGrouping()
    }
    
    @IBAction func deleteTable(_ sender: AnyObject)
    {
        undoer.beginUndoGrouping()
        undoer.setActionName("Delete Chair")
        changeParent(theNode!, to: nil)
        undoer.endUndoGrouping()
    }
    

    /// A menu action to put the controller in `.Moving(.Wall)` mode.
    @objc func editWallPosition(_ sender: AnyObject?) {
        editMode = .moving(.Wall)
    }
    
    /// A menu action to put the controller in `.Resizing(.Wall)` mode.
    @objc func editWallSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Wall, .none)
    }
    
    /// A menu action to put the controller in `.Resizing(.Picture)` mode.
    @objc func editFrameSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Picture, .none)
    }
    
    @objc func editImageSize(_ sender: AnyObject?)
    {
        editMode = .resizing(.Image, .none)
     }
    
    /// A menu action to put the controller in `.Moving(.Picture)` mode.
    @IBAction func editFramePosition(_ sender: AnyObject?)
    {
        editMode = .moving(.Picture)
        let wall = theNode!.parent!
        for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid && $0.name != nil}) {
            flattenPicture(node)
        }
    }
    
    @IBAction func editBoxPosition(_ sender: AnyObject) {
        editMode = .moving(.Box)
    }
    
    @IBAction func editBoxSize(_ sender: AnyObject) {
        editMode = .resizing(.Box, .none)
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
   
    @objc func menuBarClicked(_ info: AnyObject)
    {
//        editMode = .none
    }
    
    
}
