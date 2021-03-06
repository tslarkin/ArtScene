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
    
    /// Set `editMode` and the cursor image based on modifier keys.
    override func flagsChanged(with theEvent: NSEvent) {
        if inDrag { return }
        if case EditMode.getInfo = editMode { return }
        if case EditMode.placing(.Chair) = editMode { return }
        let controlAlone = checkModifierFlags(theEvent, flag: .control)
        if controlAlone {
            NSCursor.contextualMenu.set()
            editMode = .contextualMenu
        } else {
            let commandAlone = checkModifierFlags(theEvent, flag: .command)
            if commandAlone && nodeType(mouseNode) != .Box {
                NSCursor.pointingHand.set()
                editMode = .selecting
                mouseNode = nil
            } else {
                let optionDown =  checkModifierFlags(theEvent, flag: .option)
                if optionDown && nodeType(mouseNode) == .Image {
                    resizeCursor.set()
                }
                NSCursor.arrow.set()
                editMode = .none
                mouseMoved(with: theEvent)
           }
        }
        
    }
    
    func makePictureMenu() -> NSMenu
    {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let sizes = ["16x16", "16x20", "20x16", "20x20", "20x24", "24x20", "24x24"]
        for size in sizes {
            menu.addItem(withTitle: size, action: #selector(ArtSceneViewController.reframePicture(_:)), keyEquivalent: "")
        }
        menu.addItem(NSMenuItem.separator())
        if controller.theNode!.childNode(withName: "Frame", recursively: false)!.isHidden {
            menu.addItem(withTitle: "Show Frame", action: #selector(ArtSceneViewController.showFrame(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Hide Frame", action: #selector(ArtSceneViewController.hideFrame(_:)), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Nudge Frame Size", action: #selector(ArtSceneViewController.editFrameSize(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Nudge Image Size", action: #selector(ArtSceneViewController.editImageSize(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Nudge Position", action: #selector(ArtSceneViewController.editFramePosition(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
       if mouseNode?.childNode(withName: "Spotlight", recursively: false) == nil {
            menu.addItem(withTitle: "Add Spotlight", action: #selector(ArtSceneViewController.addSpotlight(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Remove Spotlight", action: #selector(ArtSceneViewController.removeSpotlight(_:)), keyEquivalent: "")
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Replace Picture…", action: #selector(ArtSceneViewController.replacePicture(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Delete Picture", action: #selector(ArtSceneView.deletePictures(_:)), keyEquivalent: "")
        return menu
    }
    
    @objc func addGrid(_ sender: AnyObject)
    {
        mouseNode?.setGrid()
        controller.hideGrids()
    }
    
    @objc func removeGrid(_ sender: AnyObject)
    {
        mouseNode!.removeGrid()
    }
    
    /// Main logic for returning a menu appropriate to the context.
    override func menu(for event: NSEvent) -> NSMenu? {
        controller.editMode = .none
        let p = self.convert(event.locationInWindow, from: nil)
        var hitResults: [SCNHitTestResult]
        if #available(OSX 10.13, *) {
            hitResults = hitTest(p, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
        } else {
            hitResults = hitTest(p, options: nil)
        }
        hitResults = hitResults.filter({ nodeType($0.node) != .Back && nodeType($0.node) != .Grid})
        hitResults = hitResults.filter({ nodeType($0.node) != .Picture || !theFrame($0.node).isHidden})
        let imageHit = hitOfType(hitResults, type: .Image)
        let pictureHit = hitOfType(hitResults, type: .Picture)
        var picture: SCNNode? = nil
        if imageHit != nil {
            picture = pictureOf(imageHit!.node)
        } else if pictureHit != nil {
            picture = pictureHit!.node
        }
        if let picture = picture {
            controller.theNode = picture
            if selection.contains(picture) && selection.count > 1 {
                return super.menu(for: event)
            } else {
                mouseNode = picture
                return makePictureMenu()
            }
        } else if let boxHit = hitOfType(hitResults, type: .Box) {
            controller.theNode = boxHit.node
            mouseNode = boxHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Box", action: #selector(ArtSceneViewController.deleteBox(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Box Color", action: #selector(ArtSceneViewController.pickBoxColor(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Box Size", action: #selector(ArtSceneViewController.editBoxSize(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Box Position", action: #selector(ArtSceneViewController.editBoxPosition(_:)), keyEquivalent: "")
           return menu
        }  else if let tableHit = hitOfType(hitResults, type: .Table) {
            controller.theNode = tableHit.node
            mouseNode = tableHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Table", action: #selector(ArtSceneViewController.deleteBox(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Table Color", action: #selector(ArtSceneViewController.pickTableColor(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Table Size", action: #selector(ArtSceneViewController.editBoxSize(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Table Position", action: #selector(ArtSceneViewController.editBoxPosition(_:)), keyEquivalent: "")
            return menu
        } else if let chairHit = hitOfType(hitResults, type: .Chair) {
            controller.theNode = chairHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Chair", action: #selector(ArtSceneViewController.deleteChair(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Chair Color", action: #selector(ArtSceneViewController.pickChairColor(_:)), keyEquivalent: "")
           return menu
        } else if let wallHit = hitOfType(hitResults, type: .Wall) {
            let menu = NSMenu()
            menu.autoenablesItems = true
            controller.theNode = wallHit.node
            mouseNode = wallHit.node
            if controller.wallsLocked == false {
                menu.addItem(withTitle: "Nudge Wall Position", action: #selector(ArtSceneViewController.editWallPosition(_:)), keyEquivalent: "")
                menu.addItem(withTitle: "Nudge Wall Size", action: #selector(ArtSceneViewController.editWallSize(_:)), keyEquivalent: "")
                menu.addItem(withTitle: "Rotate Wall CW", action: #selector(ArtSceneViewController.rotateWallCW), keyEquivalent: "")
                menu.addItem(withTitle: "Rotate Wall CCW", action: #selector(ArtSceneViewController.rotateWallCCW), keyEquivalent: "")
                menu.addItem(NSMenuItem.separator())
            }
            menu.addItem(withTitle: "Wall Color", action: #selector(ArtSceneViewController.pickWallColor(_:)), keyEquivalent: "")
            if mouseNode!.hasGrid() {
                menu.addItem(withTitle: "Hide Grid", action: #selector(ArtSceneView.removeGrid(_:)), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Show Grid", action: #selector(ArtSceneView.addGrid(_:)), keyEquivalent: "")
            }
            menu.addItem(withTitle: "Add Picture", action: #selector(ArtSceneViewController.addPicture(_:)), keyEquivalent: "")
            if controller.wallsLocked == false {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: "Delete Wall", action: #selector(ArtSceneViewController.deleteWall(_:)), keyEquivalent: "")
            }
            mouseClickLocation = wallHit.localCoordinates
            return menu
        } else if let floorHit = hitOfType(hitResults, type: .Floor) {
            let menu = NSMenu()
            menu.autoenablesItems = true
            let addItem = NSMenuItem(title: "Add", action: nil, keyEquivalent: "")
            menu.addItem(addItem)
            let addMenu = NSMenu()
            menu.setSubmenu(addMenu, for: addItem)
            addMenu.addItem(withTitle: "Box", action: #selector(ArtSceneViewController.addBox(_:)), keyEquivalent: "")
            addMenu.addItem(withTitle: "Chair", action: #selector(ArtSceneViewController.addChair(_:)), keyEquivalent: "")
            addMenu.addItem(withTitle: "Table", action: #selector(ArtSceneViewController.addTable(_:)), keyEquivalent: "")
            if controller.wallsLocked == false {
                addMenu.addItem(withTitle: "Wall", action: #selector(ArtSceneViewController.addWall(_:)), keyEquivalent: "")
            }
           if controller.wallsLocked == true {
                menu.addItem(withTitle: "Unlock Walls", action: #selector(ArtSceneViewController.unlockWallsWithConfirmation), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Lock Walls", action: #selector(ArtSceneViewController.lockWalls), keyEquivalent: "")
            }
            if grid().isHidden {
                menu.addItem(withTitle: "Show Checkerboard", action: #selector(ArtSceneView.showGrid(_:)), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Hide Checkerboard", action: #selector(ArtSceneView.hideGrid(_:)), keyEquivalent: "")
            }
            menu.addItem(withTitle: "Reset Camera", action: #selector(ArtSceneView.resetCamera(_:)), keyEquivalent: "")
            mouseClickLocation = floorHit.worldCoordinates
            return menu
        } else {
            return nil
        }
     }
    
    @objc func equalizeCenterDistances(_ sender: AnyObject?)
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
    
    @objc func equalizeGaps(_ sender: AnyObject?) {
        SCNTransaction.animationDuration = 0.5
        let pictures = selection.sorted { $0.position.x < $1.position.x }
        let wall = masterNode!.parent!
        let wallWidth = (wall.geometry as! SCNPlane).width
        let pictureWidth = pictures.map(nodeSize).reduce(0.0, { $0 + $1.width })
        let whiteSpace = wallWidth - pictureWidth
        let gap = whiteSpace / CGFloat(pictures.count + 1)
        var positionx = gap - wallWidth / 2.0
        for picture in pictures {
            let plane = thePlane(picture)
            picture.position.x = positionx + plane.width / 2.0
            positionx += plane.width + gap
        }
        
    }
    
    @objc func alignTops(_ sender: AnyObject?) {
        guard let masterNode = masterNode else { return }
        SCNTransaction.animationDuration = 0.5
        let masterPlane = theFrame(masterNode).isHidden ? thePlane(theImage(masterNode)) : thePlane(masterNode)
        let masterTop = masterNode.position.y + masterPlane.height / 2
        for picture in selection {
            let plane = theFrame(picture).isHidden ? thePlane(theImage(picture)) : thePlane(picture)
            picture.position.y = masterTop - plane.height / 2
        }
    }
    
    @objc func alignBottoms(_ sender: AnyObject?) {
        guard let masterNode = masterNode else { return }
       SCNTransaction.animationDuration = 0.5
        let masterPlane = theFrame(masterNode).isHidden ? thePlane(theImage(masterNode)) : thePlane(masterNode)
        let masterBottom = masterNode.position.y - masterPlane.height / 2
        for picture in selection {
            let plane = theFrame(picture).isHidden ? thePlane(theImage(picture)) : thePlane(picture)
            picture.position.y = masterBottom + plane.height / 2
        }
        
    }
    
    @objc func alignHCenters(_ sender: AnyObject?) {
        guard let masterNode = masterNode else { return }
        SCNTransaction.animationDuration = 0.5
        let masterCenter = masterNode.position.y
        for picture in selection {
            picture.position.y = masterCenter
        }
        
    }
    
    @objc func alignVCenters(_ sender: AnyObject?) {
        guard let masterNode = masterNode else { return }
        let masterCenter = masterNode.position.x
        for picture in selection {
            picture.position.x = masterCenter
        }
        
    }
    
}
