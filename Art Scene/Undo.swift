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
    var document: Document? { get }
    /// The edit mode of the adopting class
    var editMode: EditMode { get }
    /// The set of selected pictures, needed by `SetPosition`
    var selection: Set<SCNNode> { get set }
    var saved: Any { get set }
}

extension Undo
{
    
    func changePivot(_ node: SCNNode, from: CGFloat, to: CGFloat)
    {
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, handler: { $0.changePivot(node, from: to, to: from) })
        if node.yRotation() != to {
            node.setYRotation(to)
        }
    }
    
    func changePosition(_ node: SCNNode, from: SCNVector3, to: SCNVector3)
    {
        let undoer = document!.undoManager!
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
    
    func prepareForUndo(_ node: SCNNode)
    {
        if let undoer = document?.undoManager {
            undoer.beginUndoGrouping()
            switch editMode {
            case .resizing(_, .pivot):
                undoer.setActionName("Wall Rotation")
                saved = node.eulerAngles.y
            case .resizing(.Image, _):
                undoer.setActionName("Resizing Image of \(String(describing: node.name!))")
                saved = node.childNode(withName: "Image", recursively: false)!.size()!
            case .resizing(.Picture, _):
                undoer.setActionName("Resizing Frame of \(String(describing: node.name!))")
                saved = node.size()!
            case .resizing(.Wall, _):
                undoer.setActionName("Resizing \(String(describing: node.name!))")
                saved = (node.size()!, node.position)
            case .moving(.Picture):
                undoer.setActionName("Moving \(String(describing: node.name!))")
                if selection.contains(node) {
                    saved = selection.map{ ($0, $0.position, $0.parent!) }
                } else {
                    saved = [(node, node.position, node.parent!)]
                }
            case .moving(.Wall):
                undoer.setActionName("Moving \(String(describing: node.name!))")
                saved = node.position
            default:
                ()
            }
        }
    }
    
}
