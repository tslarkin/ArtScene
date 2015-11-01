//
//  GameViewController.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import Quartz

class ArtSceneViewController: NSViewController {
    
    @IBOutlet weak var artSceneView: ArtSceneView!
    @IBOutlet weak var document: Document?
    @IBOutlet weak var statusBar: NSTextField!
    
    
    enum EditMode {
        case Normal
        case WallSize
        case WallPosition
        case FrameSize
        case FramePosition
    }
    
    var editMode = EditMode.Normal {
        willSet(newMode) {
            status = ""
        }
    }
    
    var defaultFrameSize: CGSize = CGSize(width: 2, height: 2)
    var targetPicture: SCNNode? = nil
    var targetWall: SCNNode? = nil
    dynamic var status: NSString = ""
    
    let frameSizes = ["16x16":  CGSize(width: 16, height: 16),
        "16x20":  CGSize(width: 16, height: 20),
        "20x16":  CGSize(width: 20, height: 16),
        "20x20":  CGSize(width: 20, height: 20),
        "20x24":  CGSize(width: 20, height: 24),
        "24x20":  CGSize(width: 24, height: 20),
        "24x24":  CGSize(width: 24, height: 24)]
    
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
    }
    
    func reframePicture(sender: AnyObject?)
    {
        if let sender = sender as? NSMenuItem {
            let title = sender.title
            defaultFrameSize = frameSizes[title]!
            defaultFrameSize.width /= 12
            defaultFrameSize.height /= 12
            var size = defaultFrameSize
            reframePictureWithSize(targetPicture!, size: &size)
            document?.updateChangeCount(NSDocumentChangeType.ChangeDone)
        }
    }
    
    func addPicture(wall: SCNNode, path: String, point: SCNVector3, size: CGSize = CGSize.zero) -> SCNNode? {
        if let node = makePicture(path, size: size) {
            node.position = point
            node.position.z += 0.05
            wall.addChildNode(node)
            document?.updateChangeCount(NSDocumentChangeType.ChangeDone)
            return node
        } else {
            return nil
        }
    }
    
    func addPicture(sender: AnyObject?)
    {
        if let url = runOpenPanel() {
           self.addPicture(self.targetWall!, path: url.path!, point: self.artSceneView.mouseClickLocation!)
        }
    }
    
    func replacePicture(picture: SCNNode, path: String) {
        if  let size = picture.geometry as? SCNPlane,
            let _ = addPicture(picture.parentNode!, path: path, point: picture.position,
                size: CGSize(width: size.width, height: size.height)) {
            picture.removeFromParentNode()
        }
    }
    
    func replacePicture(sender: AnyObject?)
    {
        if let url = runOpenPanel() {
            replacePicture(targetPicture!, path: url.path!)
        }
    }
    
    func deleteWall(sender: AnyObject?) {
        editMode = .Normal
        targetWall?.removeFromParentNode()
        targetWall = nil
    }
    
    func editWallPosition(sender: AnyObject?) {
        editMode = .WallPosition
        let (_, location, _, distance) = wallInfo(targetWall!, camera: artSceneView.camera())
        status = "Wall Position: \(location); Distance: \(distance!)"
    }
    
    func editWallSize(sender: AnyObject?)
    {
        editMode = .WallSize
        let (size, _, _, _) = wallInfo(targetWall!)
        status = "Wall Size: \(size)"
    }
    
    func editFrameSize(sender: AnyObject?)
    {
        editMode = .FrameSize
        if let targetPicture = targetPicture {
            let (size, _, _) = pictureInfo(targetPicture)
            status = "Picture: \(size)"
        } else {
            status = ""
        }
    }
    
    func editFramePosition(sender: AnyObject?)
    {
        editMode = .FramePosition
        if let targetPicture = targetPicture {
            let (_, location, _) = pictureInfo(targetPicture)
            status = "Picture Location: \(location)"
        } else {
            status = ""
        }
    }
    
    func doFrameEditPosition(theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let targetPicture = targetPicture {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 1.0 / 48.0 : 1.0 / 12.0
                let keyChar = Int(keyString[keyString.startIndex])
                switch keyChar {
                case NSRightArrowFunctionKey:
                    targetPicture.position.x += jump
                case NSLeftArrowFunctionKey:
                    targetPicture.position.x -= jump
                case NSUpArrowFunctionKey:
                    targetPicture.position.y += jump
                case NSDownArrowFunctionKey:
                    targetPicture.position.y -= jump
                default:
                    return
                }
                let (_, location, _) = pictureInfo(targetPicture)
                status = "Picture Location: \(location)"
        }
    }
    
    func doWallEditPosition (theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let targetWall = targetWall {
                let modifiers = theEvent.modifierFlags
                let shift = modifiers.contains(.ShiftKeyMask)
                let jump: CGFloat = shift ? 0.1 : 1.0
                let rotation: CGFloat = (shift ? 1 : 10) / r2d
                let keyChar = Int(keyString[keyString.startIndex])
                SCNTransaction.setAnimationDuration(0.5)
                if modifiers.contains(.CommandKeyMask) {
                    switch keyChar {
                    case NSLeftArrowFunctionKey:
                        SCNTransaction.setAnimationDuration(0.2)
                        targetWall.eulerAngles.y += rotation
                    case NSRightArrowFunctionKey:
                        SCNTransaction.setAnimationDuration(0.2)
                        targetWall.eulerAngles.y -= rotation
                    default:
                        super.keyDown(theEvent)
                    }
                    
                } else {
                    switch keyChar {
                    case NSUpArrowFunctionKey:
                        moveNode(-jump, deltaRight: 0.0, node: targetWall)
                    case NSDownArrowFunctionKey:
                        moveNode(jump, deltaRight: 0.0, node: targetWall)
                    case NSLeftArrowFunctionKey:
                        moveNode(0, deltaRight: jump, node: targetWall)
                    case NSRightArrowFunctionKey:
                        moveNode(0, deltaRight: -jump, node: targetWall)
                    default: break
                    }
                }
                let (_, location, _, distance) = wallInfo(targetWall, camera: artSceneView.camera())
                status = "Wall Position: \(location); Distance: \(distance!)"
        }
    }
    
    func doFrameEditSize(theEvent: NSEvent)
    {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let targetPicture = targetPicture,
            let plane = targetPicture.geometry as! SCNPlane? {
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
                reframePictureWithSize(targetPicture, size: &size)
                let (newsize, _, _) = pictureInfo(targetPicture)
                status = "Picture Size: \(newsize)"
        }
    }
    
    func doWallEditSize(theEvent: NSEvent)
    {
        if let targetWall = targetWall,
            let keyString = theEvent.charactersIgnoringModifiers?.utf16,
            let plane = targetWall.geometry as! SCNPlane? {
            var newPlane: SCNPlane? = nil
//            var yoffset: CGFloat = 0.0
//            var xoffset: CGFloat = 0.0
            let modifiers = theEvent.modifierFlags
            let shift = modifiers.contains(.ShiftKeyMask)
            let jump: CGFloat = shift ? 0.1 : 1.0
            let keyChar = Int(keyString[keyString.startIndex])
            switch keyChar {
            case NSUpArrowFunctionKey:
                newPlane = SCNPlane(width: plane.width, height: plane.height + jump)
                targetWall.position.y += jump / 2
//                yoffset = -jump / 2
            case NSDownArrowFunctionKey:
                targetWall.position.y -= jump / 2
                newPlane = SCNPlane(width: plane.width, height: plane.height - jump)
//                yoffset = jump / 2
            case NSRightArrowFunctionKey:
                newPlane = SCNPlane(width: plane.width + jump, height: plane.height)
//                xoffset = jump / 2
            case NSLeftArrowFunctionKey:
                newPlane = SCNPlane(width: plane.width - jump, height: plane.height)
//                xoffset = -jump / 2
            default:
                super.keyDown(theEvent)
            }
            targetWall.geometry = newPlane
//            for child in targetWall.childNodes {
//                if child.name == "Picture" {
//                    child.position.y += yoffset
//                    child.position.x += xoffset
//                } else if child.name == "Pointer" {
//                    child.position.x += xoffset
//                }
//            }
            let (size, _, _, _) = wallInfo(targetWall)
            status = "Wall Size: \(size)"
        }
    }

    func moveSelection(charCode: Int, shift: Bool) {
        let selection = artSceneView.selection
        let jump: CGFloat = shift ? 0.25 / 12.0 : 1.0 / 12.0
        for node in selection {
            switch charCode {
            case NSLeftArrowFunctionKey:
                node.position.x -= jump
            case NSRightArrowFunctionKey:
                node.position.x += jump
            case NSUpArrowFunctionKey:
                node.position.y += jump
            case NSDownArrowFunctionKey:
                node.position.y -= jump
            default:
                break
            }
        }
        if let node = artSceneView.masterNode,
            let plane = node.parentNode?.geometry as? SCNPlane {
            status = "{ \(convertToFeetAndInches(node.position.x + plane.width / 2)), "
                + "\(convertToFeetAndInches(node.position.y + plane.height / 2)) }"
        }
    }
    
    func updateCameraStatus() {
        let camera = artSceneView.camera()
        let x = convertToFeetAndInches(camera.position.x)
        let y = convertToFeetAndInches(camera.position.y)
        let z = convertToFeetAndInches(camera.position.z)
        let rot = camera.eulerAngles.y * r2d
        let rot1 = String(format: "%.0f°", rot < 0 ? rot + 360 : rot)
        status = "Camera: " + "[\(x), \(y), \(z)] \(rot1)"
    }
    
    func doCameraEdit(theEvent: NSEvent) {
        if let keyString = theEvent.charactersIgnoringModifiers?.utf16 {
            let modifiers = theEvent.modifierFlags
            let charCode = Int(keyString[keyString.startIndex])
            if modifiers.contains(.AlternateKeyMask) {
                moveSelection(charCode, shift: modifiers.contains(.ShiftKeyMask))
                return
            }
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
                let u = crossProduct(v, b: SCNVector3(0, 1, 0))
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
    
    override func keyDown(theEvent: NSEvent)
    {
        if theEvent.modifierFlags.contains(.NumericPadKeyMask) {
            switch editMode {
            case .Normal:
                doCameraEdit(theEvent)
            case .WallPosition:
                doWallEditPosition(theEvent)
            case .WallSize:
                doWallEditSize(theEvent)
            case .FrameSize:
                doFrameEditSize(theEvent)
            case .FramePosition:
                doFrameEditPosition(theEvent)
            }
            artSceneView.document?.updateChangeCount(NSDocumentChangeType.ChangeDone)

        }
    }
}