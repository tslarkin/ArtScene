//
//  Undo.swift
//  Art Scene
//
//  Created by Timothy Larkin on 11/3/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import Cocoa

/**
 A protocol to support Undo. The nodes have four properties that are undoable.
 1. Rotation, which applies only to walls;
 1. Position, which is effectively an x, z coordinate for a wall, and an x, y coordinate for a picture;
 1. Size, which is the size of a node's geometry.
 1. Parent. Setting this to `nil` removes the node from the scene.
 
 The protocol is adopted by `ArtSceneView` and `ArtSceneViewController`.
 
 Each of the four methods requires a corresponding method, the original method name suffixed by
 `1`. Since each of the methods requires two arguments, the node and a new value for the property,
 the undo registration cannot simply call the set method itself. It calls a dummy function, passing 
 the two arguments in a dictionary, which uses the dictionary values to call the original method.
 
 Due to some weirdness in Swift, these dummy functions crash if they are defined in the protocol
 extension, so they have to be fulfilled by the the adopting class.
 */

protocol Undo : AnyObject
{
    /// The scene document
    var document: Document! { get }
    /// The edit mode of the adopting class
    var editMode: EditMode { get }
    /// The set of selected pictures, needed by `SetPosition`
    var selection: Array<SCNNode> { get set }
}

extension Undo
{
    func checkModifierFlags(_ event: NSEvent, flag: NSEvent.ModifierFlags.Element, exclusive: Bool = true)->Bool
    {
        let theFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        let flagDown =  exclusive ? (theFlags.contains(flag) && theFlags.subtracting([flag]).isEmpty) : theFlags.contains(flag)
        return flagDown
    }
    
    func changePivot(_ node: SCNNode, delta: CGFloat)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changePivot(node, delta: -delta) })
        node.yRotation += delta
    }
    
    func changePosition(_ node: SCNNode, delta: SCNVector3, povAngle: CGFloat = 0.0)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changePosition(node, delta: SCNVector3Make(-delta.x, -delta.y, -delta.z))})
        let d = rotate(vector: delta, axis: SCNVector3Make(0, 1, 0), angle: povAngle)
        node.position = node.position + d
    }
    
    func changeVolume(_ node: SCNNode, to: SCNVector3) {
        let undoer = document!.undoManager!
        let box = node.geometry as! SCNBox
        let oldVolume = SCNVector3Make(box.width, box.height, box.length)
        undoer.registerUndo(withTarget: self, handler: { $0.changeVolume(node, to: oldVolume) })
        box.width = to.x
        box.height = to.y
        box.length = to.z
    }
    
    func changeSize(_ node: SCNNode, delta: CGSize)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changeSize(node, delta: CGSize(width: -delta.width, height: -delta.height)) })
        node.setSize(node.size()! + delta)
    }
    
    func changeParent(_ node: SCNNode, to: SCNNode?)
    {
        let parent = node.parent
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changeParent(node, to: parent) })
        if let parent = to {
            parent.addChildNode(node)
        } else {
            node.removeFromParentNode()
        }
    }
    
    func replaceNode(_ node: SCNNode, with: SCNNode)
    {
        let parent = node.parent
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.replaceNode(with, with: node) })
        parent?.replaceChildNode(node, with: with)
    }
    
    func changePictureSize(_ node: SCNNode, to: CGSize)
    {
        let size = node.size()!
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self,
                            handler: { $0.changePictureSize(node, to: size) })
        (self as! ArtSceneViewController).reframePictureWithSize(node, newsize: to)
    }
    
    func changeImageSize(_ node: SCNNode,to: CGSize)
    {
        let size = node.size()!
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self,
                            handler: { $0.changeImageSize(node, to: size) })
            (self as! ArtSceneViewController).reframeImageWithSize(node, newsize: to)
    }
    
    func actionName(_ node: SCNNode, _ editMode: EditMode)->String?
    {
        var name: String?
        switch editMode {
        case .none: name = "No Action"
        case .resizing(.Wall, .pivot):
            name = "Wall Rotation"
        case .resizing(.Box, .pivot):
            name = "Box Rotation"
        case .resizing(.Image, _):
            name = "Resizing Image"
        case .resizing(.Picture, _):
            name = "Resizing Frame of \(String(describing: node.name!))"
        case .resizing(.Wall, _), .resizing(.Box, _):
            name = "Resizing \(String(describing: node.name!))"
        case .moving(.Picture), .moving(.Wall), .moving(.Box):
            name = "Moving \(String(describing: node.name!))"
       default: ()
        }
        return name
    }
    
    func prepareForUndo(_ node: SCNNode)
    {
        let undoer = document!.undoManager!
        undoer.beginUndoGrouping()
        undoer.setActionName(actionName(node, editMode)!)
    }
    
}
