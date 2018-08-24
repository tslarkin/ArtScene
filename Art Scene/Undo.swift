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
    
    func changePivot(_ node: SCNNode, from: CGFloat, to: CGFloat)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changePivot(node, from: to, to: from) })
        if node.yRotation != to {
            node.yRotation = to
        }
    }
    
    func changePosition(_ node: SCNNode, from: SCNVector3, to: SCNVector3)
    {
        let undoer = document!.undoManager!
//        undoer.setActionName(actionName(node, editMode)!)
        undoer.registerUndo(withTarget: self, handler: { $0.changePosition(node, from: to, to: from) })
        if node.position != to {
            node.position = to
        }
    }
        
    func changeSize(_ node: SCNNode, from: CGSize, to: CGSize)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changeSize(node, from: to, to: from) })
        if node.size()! != to {
            node.setSize(to)
        }
    }
    
    func changeParent(_ node: SCNNode, from: SCNNode?, to: SCNNode?)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changeParent(node, from: to, to: from) })
        if let parent = to {
            parent.addChildNode(node)
        } else {
            node.removeFromParentNode()
        }
    }
    
    func changePictureSize(_ node: SCNNode, from:CGSize, to: CGSize)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self,
                            handler: { $0.changePictureSize(node, from: to, to: from) })
        if from != to {
            (self as! ArtSceneViewController).reframePictureWithSize(node, newsize: to)
        }
    }
    
    func changeImageSize(_ node: SCNNode, from: CGSize, to: CGSize)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self,
                            handler: { $0.changeImageSize(node, from: to, to: from) })
        if from != to {
            (self as! ArtSceneViewController).reframeImageWithSize(node, newsize: to)
        }

    }
    
    func changeParent(_ node: SCNNode, from: SCNNode, to: SCNNode)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self,
                            handler: { $0.changeParent(node, from: to, to: from) })
        if from != to {
            node.removeFromParentNode()
            to.addChildNode(node)
        }

    }
    
    func actionName(_ node: SCNNode, _ editMode: EditMode)->String?
    {
        var name: String?
        switch editMode {
        case .none: name = "No Action"
        case .resizing(_, .pivot):
            name = "Wall Rotation"
        case .resizing(.Image, _):
            name = "Resizing Image"
        case .resizing(.Picture, _):
            name = "Resizing Frame of \(String(describing: node.name!))"
        case .resizing(.Wall, _):
            name = "Resizing \(String(describing: node.name!))"
        case .moving(.Picture):
            name = "Moving \(String(describing: node.name!))"
        case .moving(.Wall):
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
