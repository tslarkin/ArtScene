//
//  GameViewMenu.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/15/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit
import SpriteKit

/**
Extension for support of contextual menus and their actions.
*/
extension ArtSceneView {
    
    /// Set `editMode` and the cursor image based on modifier keys.
    override func flagsChanged(with theEvent: NSEvent) {
        if inDrag { return }
		if editTool == .keyboard { return }
        if case EditMode.getInfo = editMode { return }
        if case EditMode.placing(.Chair) = editMode { return }
        let controlAlone = checkModifierFlags(theEvent, flag: .control)
        if controlAlone {
            NSCursor.contextualMenu.set()
            editMode = .contextualMenu
        } else {
            let commandAlone = checkModifierFlags(theEvent, flag: .command)
            if commandAlone && nodeType(selectedNode) != .Box {
                NSCursor.pointingHand.set()
                editMode = .selecting
                selectedNode = nil
            } else {
                let optionDown =  checkModifierFlags(theEvent, flag: .option)
                if optionDown && nodeType(selectedNode) == .Image {
                    resizeCursor.set()
                }
                NSCursor.arrow.set()
                editMode = .none
                mouseMoved(with: theEvent)
           }
        }
        
    }
	
	// MARK: Create Menus
    
    func makePictureMenu() -> NSMenu
    {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let sizes = ["16x16", "16x20", "20x16", "20x20", "20x24", "24x20", "24x24"]
        for size in sizes {
            menu.addItem(withTitle: size, action: #selector(ArtSceneView.reframePicture(_:)), keyEquivalent: "")
        }
        menu.addItem(NSMenuItem.separator())
        if selectedNode!.childNode(withName: "Frame", recursively: false)!.isHidden {
            menu.addItem(withTitle: "Show Frame", action: #selector(ArtSceneView.showFrame(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Hide Frame", action: #selector(ArtSceneView.hideFrame(_:)), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Nudge Frame Size", action: #selector(ArtSceneView.editFrameSize(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Nudge Image Size", action: #selector(ArtSceneView.editImageSize(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Nudge Position", action: #selector(ArtSceneView.editFramePosition(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
       if selectedNode?.childNode(withName: "Spotlight", recursively: false) == nil {
            menu.addItem(withTitle: "Add Spotlight", action: #selector(ArtSceneView.addSpotlight(_:)), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Remove Spotlight", action: #selector(ArtSceneView.removeSpotlight(_:)), keyEquivalent: "")
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Replace Picture…", action: #selector(ArtSceneView.replacePicture(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Delete Picture", action: #selector(ArtSceneView.deletePictures(_:)), keyEquivalent: "")
        return menu
    }
    
    /// Main logic for returning a menu appropriate to the context.
    override func menu(for event: NSEvent) -> NSMenu? {
		closeKeyboardUndo()
        editMode = .none
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
            selectedNode = picture
            if selection.contains(picture) && selection.count > 1 {
				// Return the menu from the ActionMenu.xib
                return super.menu(for: event)
            } else {
                selectedNode = picture
                return makePictureMenu()
            }
        } else if let boxHit = hitOfType(hitResults, type: .Box) {
            selectedNode = boxHit.node
            selectedNode = boxHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Box", action: #selector(ArtSceneView.deleteBox(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Box Color", action: #selector(ArtSceneView.pickBoxColor(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Box Size", action: #selector(ArtSceneView.editBoxSize(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Box Position", action: #selector(ArtSceneView.editBoxPosition(_:)), keyEquivalent: "")
           return menu
        }  else if let tableHit = hitOfType(hitResults, type: .Table) {
            selectedNode = tableHit.node
            selectedNode = tableHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Table", action: #selector(ArtSceneView.deleteBox(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Table Color", action: #selector(ArtSceneView.pickTableColor(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Table Size", action: #selector(ArtSceneView.editBoxSize(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Nudge Table Position", action: #selector(ArtSceneView.editBoxPosition(_:)), keyEquivalent: "")
            return menu
        } else if let chairHit = hitOfType(hitResults, type: .Chair) {
            selectedNode = chairHit.node
            let menu = NSMenu()
            menu.autoenablesItems = true
            menu.addItem(withTitle: "Delete Chair", action: #selector(ArtSceneView.deleteChair(_:)), keyEquivalent: "")
            menu.addItem(withTitle: "Chair Color", action: #selector(ArtSceneView.pickChairColor(_:)), keyEquivalent: "")
           return menu
        } else if let wallHit = hitOfType(hitResults, type: .Wall) {
            let menu = NSMenu()
            menu.autoenablesItems = true
            selectedNode = wallHit.node
            selectedNode = wallHit.node
            if wallsLocked == false {
                menu.addItem(withTitle: "Nudge Wall Position", action: #selector(ArtSceneView.editWallPosition(_:)), keyEquivalent: "")
                menu.addItem(withTitle: "Nudge Wall Size", action: #selector(ArtSceneView.editWallSize(_:)), keyEquivalent: "")
                menu.addItem(withTitle: "Rotate Wall CW", action: #selector(ArtSceneView.rotateWallCW), keyEquivalent: "")
                menu.addItem(withTitle: "Rotate Wall CCW", action: #selector(ArtSceneView.rotateWallCCW), keyEquivalent: "")
                menu.addItem(NSMenuItem.separator())
            }
            menu.addItem(withTitle: "Wall Color", action: #selector(ArtSceneView.pickWallColor(_:)), keyEquivalent: "")
            if selectedNode!.hasGrid() {
                menu.addItem(withTitle: "Hide Grid", action: #selector(ArtSceneView.removeGrid(_:)), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Show Grid", action: #selector(ArtSceneView.addGrid(_:)), keyEquivalent: "")
            }
            menu.addItem(withTitle: "Add Picture", action: #selector(ArtSceneView.addPicture(_:)), keyEquivalent: "")
            if wallsLocked == false {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: "Delete Wall", action: #selector(ArtSceneView.deleteWall(_:)), keyEquivalent: "")
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
            addMenu.addItem(withTitle: "Box", action: #selector(ArtSceneView.addBox(_:)), keyEquivalent: "")
            addMenu.addItem(withTitle: "Chair", action: #selector(ArtSceneView.addChair(_:)), keyEquivalent: "")
            addMenu.addItem(withTitle: "Table", action: #selector(ArtSceneView.addTable(_:)), keyEquivalent: "")
            if wallsLocked == false {
                addMenu.addItem(withTitle: "Wall", action: #selector(ArtSceneView.addWall(_:)), keyEquivalent: "")
            }
           if wallsLocked == true {
                menu.addItem(withTitle: "Unlock Walls", action: #selector(ArtSceneView.unlockWallsWithConfirmation), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: "Lock Walls", action: #selector(ArtSceneView.lockWalls), keyEquivalent: "")
            }
            if grid.isHidden {
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
	
	// MARK: Menu Actions

	@IBAction func projection(_ sender: AnyObject) {
		if let cam = camera.camera {
			cam.usesOrthographicProjection = !cam.usesOrthographicProjection
		}
	}
	
	@objc func addGrid(_ sender: AnyObject)
	{
		selectedNode?.setGrid()
		hideGrids()
	}
	
	@objc func removeGrid(_ sender: AnyObject)
	{
		selectedNode!.removeGrid()
	}
	
	/// Sets the status line from the position of `node`.
	func showNodePosition(_ node: SCNNode) {
		let wall = node.parent
		let plane = wall?.geometry as! SCNPlane
		let x: CGFloat = node.position.x + plane.width / 2.0
		let y: CGFloat = node.position.y + plane.height / 2.0
		let xcoord = convertToFeetAndInches(x)
		let ycoord = convertToFeetAndInches(y)
		let display = makeDisplay(title: "Picture",
								  items: [("x", xcoord), ("y", ycoord)],
								  width: 175)
		display.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
		hudUpdate = display
	}
	

	// MARK: - Spotlights
	@IBAction func addSpotlight(_ sender: AnyObject)
	{
		if let node = selectedNode, nodeType(node) == .Picture, node.childNode(withName: "Spotlight", recursively: false) == nil {
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
			light.color = NSColor(white: spotlightIntensity, alpha: 1.0)
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
	
	@IBAction func resetCamera(_ sender: AnyObject)
	{
		camera.rotation = SCNVector4Zero
		camera.position = SCNVector3Make(0.0, 6.0, 0.0)
	}
	
	@IBAction func removeSpotlight(_ sender: AnyObject)
	{
		if let node = selectedNode, nodeType(node) == .Picture, let spot = node.childNode(withName: "Spotlight", recursively: false) {
			spot.removeFromParentNode()
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
			let node = selectedNode!
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
		_hideFrame(selectedNode!)
	}
	
	/// Show the frame
	@objc func showFrame(_ sender: AnyObject?) {
		if let child = selectedNode?.childNode(withName: "Frame", recursively: false) {
			child.isHidden = false
		}
		if let child = selectedNode?.childNode(withName: "Matt", recursively: false) {
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
			self.addPicture(self.selectedNode!, path: url.path, point: self.mouseClickLocation!)
		}
	}
	
	/// Delete all the pictures in the selection if the selection contains the mouseNode.
	/// Otherwise delete only the `mouseNode`.
	@IBAction func deletePictures(_ sender: AnyObject?)
	{
		undoer.beginUndoGrouping()
		if let node = selectedNode, selection.contains(node) {
			undoer.setActionName("Delete Selection")
			for picture in selection {
				setNodeEmission(picture, color: NSColor.black)
				changeParent(picture, to: nil)
			}
			selection = []
		} else if let node = selectedNode, nodeType(node) == NodeType.Picture {
			undoer.setActionName("Delete Picture")
			changeParent(node, to: nil)
		}
		undoer.endUndoGrouping()
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
			replacePicture(selectedNode!, path: url.path)
		}
	}
	
	@objc func deleteWall(_ sender: AnyObject?) {
		editMode = .none
		undoer.beginUndoGrouping()
		undoer.setActionName("Delete Wall")
		changeParent(selectedNode!, to: nil)
		undoer.endUndoGrouping()
		selectedNode = nil
	}
	
	@IBAction func addWall(_ sender: AnyObject?) {
		undoer.beginUndoGrouping()
		undoer.setActionName("Add Wall")
		let wallNode = makeWall(at: mouseClickLocation!)
		changeParent(wallNode, to: scene!.rootNode)
		undoer.endUndoGrouping()
	}
	
	@IBAction func addBox(_ sender: AnyObject)
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Add Box")
		let boxNode = makeBox(at: mouseClickLocation!)
		changeParent(boxNode, to: scene!.rootNode)
		undoer.endUndoGrouping()
	}
	
	@IBAction func deleteBox(_ sender: AnyObject)
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Delete Box")
		changeParent(selectedNode!, to: nil)
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
		let boxNode = makeChair(at: mouseClickLocation!)
		//        boxNode.yRotation = -camera().yRotation - .pi / 2.0
		changeParent(boxNode, to: scene!.rootNode)
		undoer.endUndoGrouping()
	}
	
	@IBAction func deleteChair(_ sender: AnyObject)
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Delete Chair")
		changeParent(selectedNode!, to: nil)
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
		let boxNode = makeTable(at: mouseClickLocation!)
		boxNode.yRotation = -camera.yRotation - .pi / 2.0
		changeParent(boxNode, to: scene!.rootNode)
		undoer.endUndoGrouping()
	}
	
	@IBAction func deleteTable(_ sender: AnyObject)
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Delete Chair")
		changeParent(selectedNode!, to: nil)
		undoer.endUndoGrouping()
	}
	
	
	/// A menu action to put the controller in `.Moving(.Wall)` mode.
	@objc func editWallPosition(_ sender: AnyObject?) {
		editTool = .keyboard
		editMode = .moving(.Wall)
	}
	
	/// A menu action to put the controller in `.Resizing(.Wall)` mode.
	@objc func editWallSize(_ sender: AnyObject?)
	{
		editTool = .keyboard
		editMode = .resizing(.Wall, .none)
	}
	
	/// A menu action to put the controller in `.Resizing(.Picture)` mode.
	@objc func editFrameSize(_ sender: AnyObject?)
	{
		editTool = .keyboard
		editMode = .resizing(.Picture, .none)
	}
	
	@objc func editImageSize(_ sender: AnyObject?)
	{
		editTool = .keyboard
		editMode = .resizing(.Image, .none)
	}
	
	/// A menu action to put the controller in `.Moving(.Picture)` mode.
	@IBAction func editFramePosition(_ sender: AnyObject?)
	{
		editTool = .keyboard
		editMode = .moving(.Picture)
//		let wall = selectedNode!.parent!
//		for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid && $0.name != nil}) {
//			flattenPicture(node)
//		}
	}
	
	@IBAction func editBoxPosition(_ sender: AnyObject) {
		editTool = .keyboard
		editMode = .moving(.Box)
	}
	
	@IBAction func editBoxSize(_ sender: AnyObject) {
		editTool = .keyboard
		editMode = .resizing(.Box, .none)
	}
	
	@objc func rotateWallCW()
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Rotate Wall CW")
		changeRotation(selectedNode!, delta: -.pi / 2.0)
		undoer.endUndoGrouping()
		getInfo(selectedNode!)
	}
	
	@objc func rotateWallCCW()
	{
		undoer.beginUndoGrouping()
		undoer.setActionName("Rotate Wall CCW")
		changeRotation(selectedNode!, delta: .pi / 2.0)
		undoer.endUndoGrouping()
		getInfo(selectedNode!)
	}
	
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
		picker.setAction(#selector(ArtSceneView.setBoxColor(_:)))
		let box = selectedNode!.geometry as! SCNBox
		let color = box.firstMaterial?.diffuse.contents as! NSColor
		picker.color = color
		picker.isContinuous = true
		picker.orderFront(nil)
	}
	
	@objc func setBoxColor(_ sender: AnyObject) {
		if let sender = sender as? NSColorPanel {
			let color = sender.color
			let box = selectedNode!.geometry as! SCNBox
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
		picker.setAction(#selector(ArtSceneView.setChairColor(_:)))
		let chair = selectedNode!.childNode(withName: "Wooden_Chair", recursively: false)!
		let color = chair.geometry!.firstMaterial?.diffuse.contents as! NSColor
		picker.color = color
		picker.isContinuous = true
		picker.orderFront(nil)
	}
	
	@objc func setChairColor(_ sender: AnyObject) {
		if let sender = sender as? NSColorPanel {
			let color = sender.color
			let chair = selectedNode!.childNode(withName: "Wooden_Chair", recursively: false)!
			chair.geometry!.firstMaterial?.diffuse.contents = color
		}
	}
	
	@IBAction func pickTableColor(_ sender: AnyObject?)
	{
		let picker = NSColorPanel.shared
		picker.setTarget(self)
		picker.setAction(#selector(ArtSceneView.setTableColor(_:)))
		let top = selectedNode!.childNode(withName: "Top", recursively: false)!
		let color = top.geometry!.firstMaterial?.diffuse.contents as! NSColor
		picker.color = color
		picker.isContinuous = true
		picker.orderFront(nil)
	}
	
	@objc func setTableColor(_ sender: AnyObject) {
		if let sender = sender as? NSColorPanel {
			let color = sender.color
			var parts = [selectedNode!.childNode(withName: "Top", recursively: false)!,
						 selectedNode!.childNode(withName: "Under", recursively: false)!]
			parts.append(contentsOf: selectedNode!.childNode(withName: "Legs", recursively: false)!.childNodes)
			for part in parts {
				part.geometry!.firstMaterial?.diffuse.contents = color
			}
		}
	}
	
	
	@IBAction func pickWallColor(_ sender: AnyObject?)
	{
		let picker = NSColorPanel.shared
		picker.setTarget(self)
		picker.setAction(#selector(ArtSceneView.setColorOfWalls(_:)))
		picker.color = wallColor
		picker.isContinuous = true
		picker.orderFront(nil)
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
		let attributes = [NSAttributedString.Key.font: font]
		let string = NSAttributedString(string: "Back", attributes: attributes)
		let size = string.size()
		let text = SCNText(string: string, extrusionDepth: 0.0)
		let material = SCNMaterial()
		material.diffuse.contents = NSColor.black
		text.materials = [material]
		let back = SCNNode(geometry: text)
		back.position = SCNVector3Make(size.width / 2.0, -size.height / 2.0, -0.1)
		back.yRotation = .pi
		wallNode.yRotation = camera.yRotation
		wallNode.addChildNode(back)
		return wallNode
	}
	
	@objc func lockWalls()
	{
		if (scene?.rootNode.childNode(withName: "Lock", recursively: false)) != nil
		{
			return
		}
		wallsLocked = true
		let lock = SCNNode()
		lock.isHidden = true
		lock.name = "Lock"
		scene?.rootNode.addChildNode(lock)
	}
	
	func unlockWalls()
	{
		if let lock = scene?.rootNode.childNode(withName: "Lock", recursively: false)
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
			let (x, y, width, height, rotation, distance) = wallInfo(node, camera: camera, hitPosition: hitPosition)
			hudTable = [("↔", x), ("↕", y), ("width", width), ("height", height), ("y°", rotation), ("↑", distance!)]
			title = "Wall"
		case .Matt:
			vNode = node.parent!
			fallthrough
		case .Picture:
			let (x, y, width, height, hidden, distance) = pictureInfo(vNode, camera: camera, hitPosition: hitPosition)
			hudTable = [("↔", x), ("↕", y), ("width", width), ("height", height),
						("frame", hidden),
						("↑", distance)]
			title = "Picture"
		case .Image:
			let (width, height, name) = imageInfo(vNode)
			hudTable = [("width", width), ("height", height)]
			title = name
		case .Box:
			let (x, y, elevation, width, height, length, rotation) = boxInfo(node)
			hudTable = [("↔", x), ("↕", y), ("↑", elevation), ("width", width), ("length", length), ("height", height), ("y°", rotation)]
			title = "\(String(describing: node.name!))"
		case .Chair, .Table:
			let (x, y, _, width, height, length, rotation) = boxInfo(node)
			hudTable = [("↔", x), ("↕", y), ("width", width), ("length", length), ("height", height), ("y°", rotation)]
			title = "\(String(describing: node.name!))"
			
		default:
			return
		}
		hudUpdate = makeDisplay(title: title, items: hudTable, width: fontScaler * 220)
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
	

	/// Hide the grid
	@objc func hideGrid(_ sender: AnyObject?) {
		grid.isHidden = true
	}
	
	/// Show the grid
	@objc func showGrid(_ sender: AnyObject?) {
		grid.isHidden = false
	}
	
	@IBAction func daySky(_ sender: AnyObject)
	{
		let skybox = "miramar.jpg"
		let path = Bundle.main.pathForImageResource(skybox)!
		let image = NSImage(contentsOfFile: path)
		scene!.background.contents = image
	}
	
	@IBAction func nightSky(_ sender: AnyObject)
	{
		let skybox = "purplenebula.png"
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
		if let omni = omniLight.light {
			if omni.castsShadow {
				omni.castsShadow = false
				sender.title = "Shadow"
			} else {
				omni.castsShadow = true
				sender.title = "No Shadow"
			}
		}
	}
	

	
    
}
