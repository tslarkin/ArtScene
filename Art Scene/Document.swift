//
//  Document.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/16/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

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
        camera.xFov = 60
        camera.yFov = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "Camera"
        scene.rootNode.addChildNode(cameraNode)
        
        let wallHeight: CGFloat = 12.0
        cameraNode.position = SCNVector3(x: 0, y: 6, z: 0)
        
        // create and add a light to the scene
        let light = SCNLight()
        light.color = NSColor(white: 0.8, alpha: 1.0)
        let lightNode = SCNNode()
        lightNode.light = light
        light.type = SCNLightTypeOmni
        light.castsShadow = true
        lightNode.position = SCNVector3(x: 0, y: wallHeight * 2, z: 0)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = NSColor(white: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)
        
        let floor = SCNFloor()
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        floorNode.name = "Floor"
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor.lightGrayColor()
        floor.materials = [floorMaterial]
        floor.reflectivity = 0.1
        
        scene.rootNode.addChildNode(floorNode)
        
        // set the scene to the view
        return scene
        
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
        if scene == nil {
            scene = createDefaultScene()
        }
        sceneView.scene = scene
        // if the scene was saved with a selection, then the nodes have to revert their emissions to black
        if let children = sceneView.scene?.rootNode.childNodesPassingTest ( {  x, yes in x.geometry != nil } ) {
            for child in children {
                let material = child.geometry!.firstMaterial!
                material.emission.contents = NSColor.blackColor()
            }
        }
        let window = windowForSheet!
        window.acceptsMouseMovedEvents = true

    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override var windowNibName: String? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return "Document"
    }

    override func dataOfType(typeName: String) throws -> NSData {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        
        return NSKeyedArchiver.archivedDataWithRootObject(sceneView!.scene!)
    }

    override func readFromData(data: NSData, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        let data = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! SCNScene
        scene = data
    }

    override func printOperationWithSettings(printSettings: [String : AnyObject]) throws -> NSPrintOperation
    {
        let info = printInfo
        info.horizontalPagination = NSPrintingPaginationMode.AutoPagination
        info.verticalPagination = NSPrintingPaginationMode.AutoPagination
        let op = NSPrintOperation(view: sceneView.printView(info), printInfo: info)
        return op
    }
    
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        if menuItem.title == "Print…" {
            return sceneView.imageCacheForPrint?.count > 0
        }
        return true
    }
    

}

