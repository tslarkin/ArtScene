//
//  Document.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/16/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class Document: NSDocument {

    @IBOutlet weak var sceneView: ArtSceneView!
    
    var scene: SCNScene? = nil
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }
    
    func createDefaultScene() -> SCNScene {
        let scene = SCNScene()
        
        let camera = SCNCamera()
        camera.fieldOfView = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "Camera"
        scene.rootNode.addChildNode(cameraNode)
        
        cameraNode.position = SCNVector3(x: 0, y: 6, z: 15)
        
        // create and add a light to the scene
        let light = SCNLight()
        light.color = NSColor(white: 0.8, alpha: 1.0)
        let lightNode = SCNNode()
        lightNode.name = "Omni"
        lightNode.light = light
        light.type = SCNLight.LightType.omni
        light.castsShadow = true
        lightNode.position = cameraNode.position
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLight.LightType.ambient
        ambientLightNode.light!.color = NSColor(white: 0.5, alpha: 1.0)
        ambientLightNode.name = "Ambient"
        scene.rootNode.addChildNode(ambientLightNode)
        
        let gridNode = makeCheckerBoardFloor()
        scene.rootNode.addChildNode(gridNode)
        let floorNode = makeGrayFloor()
        scene.rootNode.addChildNode(floorNode)
        
        let wallNode = sceneView.makeWall(at: SCNVector3(x: 0.0, y: 6.0, z: 0.0))
        scene.rootNode.addChildNode(wallNode)
        
        return scene
    }
    
    func makeCheckerBoardFloor()->SCNNode {
        let transform = SCNMatrix4MakeRotation(-.pi / 2.0, 1.0, 0.0, 0.0)
        let black = SCNMaterial()
        black.diffuse.contents = NSColor.gray
        black.transparency = 0.5
        let white = SCNMaterial()
        white.diffuse.contents = NSColor.clear
        let blackTile = SCNPlane(width: 1.0, height: 1.0)
        blackTile.firstMaterial = black
        let whiteTile = SCNPlane(width: 1.0, height: 1.0)
        whiteTile.firstMaterial = white
        
        let floorNode = SCNNode()
        floorNode.name = "Grid"
        let y: CGFloat = 0.01
        floorNode.position = SCNVector3(x: 0, y: y, z: 0)
        let size = 200
        let size2 = size / 2
        var odd = false
        for x in -size2...size2 {
            for z in -size2...size2 {
                odd = !odd
                if !odd {
                    continue
                }
                let tileNode = SCNNode()
                tileNode.geometry = blackTile
                tileNode.transform = transform
                tileNode.position = SCNVector3Make(CGFloat(x), y, CGFloat(z))
                
                floorNode.addChildNode(tileNode)
            }
        }
        return floorNode
    }
    
    func makeGrayFloor()->SCNNode {
        let floor = SCNFloor()
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        floorNode.name = "Floor"
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor.lightGray
        floor.materials = [floorMaterial]
        floor.reflectivity = 0.2
        floorMaterial.transparency = 1.0
        return floorNode
    }

    override func windowControllerDidLoadNib(_ aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
        if scene == nil {
            scene = createDefaultScene()
        }
        sceneView.scene = scene
        if (scene?.rootNode.childNode(withName: "Lock", recursively: false)) != nil {
            sceneView.controller.wallsLocked = true
        }
        // if the scene was saved with a selection, then the nodes have to revert their emissions to black
        if let children = sceneView.scene?.rootNode.childNodes ( passingTest: {  x, yes in x.geometry != nil } ) {
            for child in children {
                let material = child.geometry!.firstMaterial!
                material.emission.contents = NSColor.black
            }
        }
        let window = windowForSheet!
        window.acceptsMouseMovedEvents = true

    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        
        return NSKeyedArchiver.archivedData(withRootObject: sceneView!.scene!)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        let data = NSKeyedUnarchiver.unarchiveObject(with: data) as! SCNScene
        scene = data
    }

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey : Any]) throws -> NSPrintOperation
    {
        let info = printInfo
        info.horizontalPagination = NSPrintInfo.PaginationMode.autoPagination
        info.verticalPagination = NSPrintInfo.PaginationMode.autoPagination
        let op = NSPrintOperation(view: sceneView.printView(info), printInfo: info)
        return op
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Print…" {
            return sceneView.imageCacheForPrint?.count > 0
        }
        return true
    }
    

}

