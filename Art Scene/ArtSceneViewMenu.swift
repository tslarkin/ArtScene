//
//  GameViewMenu.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/15/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

/**
Extension for support of contextual menus and their actions.
*/
extension ArtSceneView {
    
    @IBAction func addWall(_ sender: AnyObject?) {
        let wall = SCNPlane(width: 20, height: 12)
        let paint = SCNMaterial()
        paint.diffuse.contents = wallColor
        paint.isDoubleSided = false
        //            paint.locksAmbientWithDiffuse = false
        //            paint.ambient.contents = NSColor.blackColor()
        wall.materials = [paint]
        let wallNode = SCNNode(geometry: wall)
        wallNode.name = "Wall"
        wallNode.position = mouseClickLocation!
        wallNode.position.y = 6
        wallNode.castsShadow = true
        document?.undoManager?.setActionName("Add Wall")
        setParentOf(wallNode, to: scene!.rootNode)
    }
    
    @IBAction func pickWallColor(_ sender: AnyObject?)
    {
        let picker = NSColorPanel.shared()
        picker.setTarget(self)
        picker.setAction("setColorOfWalls:")
        picker.color = wallColor
        picker.isContinuous = true
        picker.orderFront(nil)
    }
    
    /// Set `editMode` and the cursor image based on modifier keys.
    override func flagsChanged(with theEvent: NSEvent) {
        if inDrag { return }
        let controlAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.control.rawValue != 0
        if controlAlone {
            NSCursor.contextualMenu().set()
            editMode = .contextualMenu
        } else {
            let commandAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.command.rawValue != 0
            if commandAlone {
                NSCursor.pointingHand().set()
                editMode = .selecting
            } else {
                let altAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.option.rawValue != 0
                if altAlone {
                    editMode = .getInfo
                    questionCursor.set()
                } else {
                    NSCursor.arrow().set()
                    editMode = .none
                }
            }
        }
        super.flagsChanged(with: theEvent)
    }
    
    func makePictureMenu() -> NSMenu
    {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let sizes = ["16x16", "16x20", "20x16", "20x20", "20x24", "24x20", "24x24"]
        for size in sizes {
            menu.addItem(withTitle: size, action: Selector("reframePicture:"), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Nudge Size", action: "editFrameSize:", keyEquivalent: "")
        menu.addItem(withTitle: "Nudge Position", action: "editFramePosition:", keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Replace Picture…", action: "replacePicture:", keyEquivalent: "")
        menu.addItem(withTitle: "Delete Picture", action: "deletePictures:", keyEquivalent: "")
        return menu
    }
    
    /// Main logic for returning a menu appropriate to the context.
    override func menu(for event: NSEvent) -> NSMenu? {
        controller.editMode = .none
        let p = self.convert(event.locationInWindow, from: nil)
        let hitResults = self.hitTest(p, options: nil)
        let pictureHit = hitOfType(hitResults, type: .Picture)
        if let picture = pictureHit?.node {
            if selection.contains(picture) && selection.count > 1 {
                return super.menu(for: event)
            } else {
                controller.theNode = picture
                return makePictureMenu()
            }
        } else if let wallHit = hitOfType(hitResults, type: .Wall) {
                let menu = NSMenu()
                menu.autoenablesItems = true
                controller.theNode = wallHit.node
                menu.addItem(withTitle: "Nudge Wall Position", action: "editWallPosition:", keyEquivalent: "")
                menu.addItem(withTitle: "Nudge Wall Size", action: "editWallSize:", keyEquivalent: "")
                menu.addItem(withTitle: "Delete Wall", action: "deleteWall:", keyEquivalent: "")
                menu.addItem(withTitle: "Wall Color", action: "pickWallColor:", keyEquivalent: "")
                menu.addItem(withTitle: "Add Picture", action: "addPicture:", keyEquivalent: "")
                mouseClickLocation = wallHit.localCoordinates
                return menu
        } else if let floorHit = hitOfType(hitResults, type: .Floor) {
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Add Wall", action: "addWall:", keyEquivalent: "")
            mouseClickLocation = floorHit.worldCoordinates
            return menu
        } else {
            return nil
        }
     }
    
    func setColorOfWalls(_ sender: AnyObject?) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            self.wallColor = color
        }
    }
    
    func equalizeCenterDistances(_ sender: AnyObject?)
    {
        SCNTransaction.animationDuration = 0.5
        let pictures = selection.sorted { $0.position.x < $1.position.x }
        let wall = masterNode!.parent!
        let width = (wall.geometry as! SCNPlane).width
        let centerDistance = width / CGFloat(selection.count + 1)
        var positionx = centerDistance - width / 2.0
        for picture in pictures {
            picture.position.x = positionx
            positionx += centerDistance
        }
    }
    
    func equalizeGaps(_ sender: AnyObject?) {
        SCNTransaction.animationDuration = 0.5
        let pictures = selection.sorted { $0.position.x < $1.position.x }
        let wall = masterNode!.parent!
        let wallWidth = (wall.geometry as! SCNPlane).width
        let pictureWidth = pictures.map(nodeSize).reduce(0.0, { $0 + $1.width })
        let whiteSpace = wallWidth - pictureWidth
        let gap = whiteSpace / CGFloat(pictures.count + 1)
        var positionx = gap - wallWidth / 2.0
        for picture in pictures {
            let plane = picture.geometry as! SCNPlane
            picture.position.x = positionx + plane.width / 2.0
            positionx += plane.width + gap
        }
        
    }
    
    func alignTops(_ sender: AnyObject?) {
        SCNTransaction.animationDuration = 0.5
        let masterPlane = masterNode?.geometry as! SCNPlane
        let masterTop = masterNode!.position.y + masterPlane.height / 2
        for picture in selection {
            let plane = picture.geometry as! SCNPlane
            picture.position.y = masterTop - plane.height / 2
        }
    }
    
    func alignBottoms(_ sender: AnyObject?) {
        SCNTransaction.animationDuration = 0.5
        let masterPlane = masterNode?.geometry as! SCNPlane
        let masterBottom = masterNode!.position.y - masterPlane.height / 2
        for picture in selection {
            let plane = picture.geometry as! SCNPlane
            picture.position.y = masterBottom + plane.height / 2
        }
        
    }
    
    func alignHCenters(_ sender: AnyObject?) {
        SCNTransaction.animationDuration = 0.5
        let masterCenter = masterNode!.position.y
        for picture in selection {
            picture.position.y = masterCenter
        }
        
    }
    
    func alignVCenters(_ sender: AnyObject?) {
        let masterCenter = masterNode!.position.x
        for picture in selection {
            picture.position.x = masterCenter
        }
        
    }
    
}
