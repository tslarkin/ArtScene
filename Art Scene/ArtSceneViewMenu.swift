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
    
    @IBAction func addWall(sender: AnyObject?) {
        let wall = SCNPlane(width: 20, height: 12)
        let paint = SCNMaterial()
        paint.diffuse.contents = wallColor
        paint.doubleSided = false
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
    
    @IBAction func pickWallColor(sender: AnyObject?)
    {
        let picker = NSColorPanel.sharedColorPanel()
        picker.setTarget(self)
        picker.setAction("setColorOfWalls:")
        picker.color = wallColor
        picker.continuous = true
        picker.orderFront(nil)
    }
    
    /// Set `editMode` and the cursor image based on modifier keys.
    override func flagsChanged(theEvent: NSEvent) {
        if inDrag { return }
        let controlAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.ControlKeyMask.rawValue != 0
        if controlAlone {
            NSCursor.contextualMenuCursor().set()
            editMode = .ContextualMenu
        } else {
            let commandAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.CommandKeyMask.rawValue != 0
            if commandAlone {
                NSCursor.pointingHandCursor().set()
                editMode = .Selecting
            } else {
                let altAlone = theEvent.modifierFlags.rawValue & NSEventModifierFlags.AlternateKeyMask.rawValue != 0
                if altAlone {
                    editMode = .GetInfo
                    questionCursor.set()
                } else {
                    NSCursor.arrowCursor().set()
                    editMode = .None
                }
            }
        }
        super.flagsChanged(theEvent)
    }
    
    func makePictureMenu() -> NSMenu
    {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let sizes = ["16x16", "16x20", "20x16", "20x20", "20x24", "24x20", "24x24"]
        for size in sizes {
            menu.addItemWithTitle(size, action: Selector("reframePicture:"), keyEquivalent: "")
        }
        menu.addItemWithTitle("Nudge Size", action: "editFrameSize:", keyEquivalent: "")
        menu.addItemWithTitle("Nudge Position", action: "editFramePosition:", keyEquivalent: "")
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItemWithTitle("Replace Picture…", action: "replacePicture:", keyEquivalent: "")
        menu.addItemWithTitle("Delete Picture", action: "deletePictures:", keyEquivalent: "")
        return menu
    }
    
    /// Main logic for returning a menu appropriate to the context.
    override func menuForEvent(event: NSEvent) -> NSMenu? {
        controller.editMode = .None
        let p = self.convertPoint(event.locationInWindow, fromView: nil)
        let hitResults = self.hitTest(p, options: nil)
        let pictureHit = hitOfType(hitResults, type: .Picture)
        if let picture = pictureHit?.node {
            if selection.contains(picture) && selection.count > 1 {
                return super.menuForEvent(event)
            } else {
                controller.theNode = picture
                return makePictureMenu()
            }
        } else if let wallHit = hitOfType(hitResults, type: .Wall) {
                let menu = NSMenu()
                menu.autoenablesItems = true
                controller.theNode = wallHit.node
                menu.addItemWithTitle("Nudge Wall Position", action: "editWallPosition:", keyEquivalent: "")
                menu.addItemWithTitle("Nudge Wall Size", action: "editWallSize:", keyEquivalent: "")
                menu.addItemWithTitle("Delete Wall", action: "deleteWall:", keyEquivalent: "")
                menu.addItemWithTitle("Wall Color", action: "pickWallColor:", keyEquivalent: "")
                menu.addItemWithTitle("Add Picture", action: "addPicture:", keyEquivalent: "")
                mouseClickLocation = wallHit.localCoordinates
                return menu
        } else if let floorHit = hitOfType(hitResults, type: .Floor) {
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItemWithTitle("Add Wall", action: "addWall:", keyEquivalent: "")
            mouseClickLocation = floorHit.worldCoordinates
            return menu
        } else {
            return nil
        }
     }
    
    func setColorOfWalls(sender: AnyObject?) {
        if let sender = sender as? NSColorPanel {
            let color = sender.color
            self.wallColor = color
        }
    }
    
    func equalizeCenterDistances(sender: AnyObject?)
    {
        SCNTransaction.setAnimationDuration(0.5)
        let pictures = selection.sort { $0.position.x < $1.position.x }
        let wall = masterNode!.parentNode!
        let width = (wall.geometry as! SCNPlane).width
        let centerDistance = width / CGFloat(selection.count + 1)
        var positionx = centerDistance - width / 2.0
        for picture in pictures {
            picture.position.x = positionx
            positionx += centerDistance
        }
    }
    
    func equalizeGaps(sender: AnyObject?) {
        SCNTransaction.setAnimationDuration(0.5)
        let pictures = selection.sort { $0.position.x < $1.position.x }
        let wall = masterNode!.parentNode!
        let wallWidth = (wall.geometry as! SCNPlane).width
        let pictureWidth = pictures.map(nodeSize).reduce(0.0, combine: { $0 + $1.width })
        let whiteSpace = wallWidth - pictureWidth
        let gap = whiteSpace / CGFloat(pictures.count + 1)
        var positionx = gap - wallWidth / 2.0
        for picture in pictures {
            let plane = picture.geometry as! SCNPlane
            picture.position.x = positionx + plane.width / 2.0
            positionx += plane.width + gap
        }
        
    }
    
    func alignTops(sender: AnyObject?) {
        SCNTransaction.setAnimationDuration(0.5)
        let masterPlane = masterNode?.geometry as! SCNPlane
        let masterTop = masterNode!.position.y + masterPlane.height / 2
        for picture in selection {
            let plane = picture.geometry as! SCNPlane
            picture.position.y = masterTop - plane.height / 2
        }
    }
    
    func alignBottoms(sender: AnyObject?) {
        SCNTransaction.setAnimationDuration(0.5)
        let masterPlane = masterNode?.geometry as! SCNPlane
        let masterBottom = masterNode!.position.y - masterPlane.height / 2
        for picture in selection {
            let plane = picture.geometry as! SCNPlane
            picture.position.y = masterBottom + plane.height / 2
        }
        
    }
    
    func alignHCenters(sender: AnyObject?) {
        SCNTransaction.setAnimationDuration(0.5)
        let masterCenter = masterNode!.position.y
        for picture in selection {
            picture.position.y = masterCenter
        }
        
    }
    
    func alignVCenters(sender: AnyObject?) {
        let masterCenter = masterNode!.position.x
        for picture in selection {
            picture.position.x = masterCenter
        }
        
    }
    
}
