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
    weak var document: Document? { get }
    /// The edit mode of the adopting class
    var editMode: EditMode { get }
    /// This is called by `SetNodeSize()` when the node is a picture
    func reframePictureWithSize(_ node: SCNNode, newsize: CGSize)
    /// The set of selected pictures, needed by `SetPosition`
    var selection: Set<SCNNode> { get set }
    func setPosition1(_ args: [String: AnyObject])
    func setPivot1(_ args: [String: AnyObject])
    func setNodeSize1(_ args: [String: AnyObject])
    func setParentOf1(_ args: [String: AnyObject])
}

extension Undo
{
    
    func setPivot(_ node: SCNNode, angle: CGFloat)
    {
        let oldAngle = node.eulerAngles.y
        let undoer = document!.undoManager!
        undoer.registerUndo(withTarget: self, selector: Selector("setPivot1:"),
            object: ["node": node, "angle": oldAngle])
        if angle != node.eulerAngles.y {
            node.eulerAngles.y = angle
        }
    }
    
    func setPosition(_ node: SCNNode, position: SCNVector3)
    {
        let undoer = document!.undoManager!
        let old = node.position
        let dict: [String: AnyObject] = ["node": node, "position": [old.x, old.y, old.z]]
        undoer.registerUndo(withTarget: self, selector: Selector("setPosition1:"), object: dict)
        if node.position.x != position.x || node.position.y != position.y || node.position.z != position.z {
            node.position = position
        }
    }
    
    func setNodeSize(_ node: SCNNode, size: CGSize)
    {
        if let geometry = node.geometry as? SCNPlane {
            let oldsize = CGSize(width: geometry.width, height: geometry.height)
            let undoer = document!.undoManager!
            let dict: [String: AnyObject] = ["node": node, "size": [oldsize.width, oldsize.height]]
            undoer.registerUndo(withTarget: self, selector: Selector("setNodeSize1:"),
                object: dict)
            if oldsize != size {
                switch nodeType(node)! {
                case .Wall:
                    // When the wall is resized, its y coordinate must be adjusted so the the bottom
                    // of the wall stays on the floor. Also, the y coordinates of the pictures have
                    // to be adjusted to keep them at the same distance above the floor.
                    let geometry = node.geometry as! SCNPlane
                    geometry.width = size.width
                    geometry.height = size.height
                    let dy2 = (size.height - oldsize.height) / 2
                    node.position.y += dy2
                    for child in node.childNodes {
                        switch nodeType(child)! {
                        case .Picture:
                            child.position.y -= dy2
                        case .Wall:
                            break
                        default: ()
                        }
                    }
                    
                case .Picture:
                    reframePictureWithSize(node, newsize: size)
                default:()
                }
            }
        }
    }
    
    func setParentOf(_ node: SCNNode, to: SCNNode?)
    {
        let undoer = document!.undoManager!
        if let parent = node.parent {
            let dict = ["node": node, "parent": parent]
            undoer.registerUndo(withTarget: self, selector: Selector("setParentOf1:"), object: dict)
            node.removeFromParentNode()
        } else {
            let dict = ["node": node]
            undoer.registerUndo(withTarget: self, selector: Selector("setParentOf1:"), object: dict)
        }
        if let newParent = to {
            newParent.addChildNode(node)
        }
        if selection.contains(node) {
            selection.remove(node)
            setNodeEmission(node, color: NSColor.black)
        }
    }
    
    func prepareForUndo(_ node: SCNNode)
    {
        if let undoer = document?.undoManager {
            undoer.removeAllActions()
            undoer.beginUndoGrouping()
            switch editMode {
            case .resizing(_, .pivot):
                undoer.setActionName("Wall Rotation")
                setPivot(node, angle: node.eulerAngles.y)
            case .resizing(_, _):
                if let geometry = node.geometry as? SCNPlane {
                    undoer.setActionName("Resizing \(node.name)")
                    setNodeSize(node, size: CGSize(width: geometry.width, height: geometry.height) )
                }
            case .moving(_):
                undoer.setActionName("Moving \(node.name)")
                if selection.contains(node) {
                    for node in selection {
                        setPosition(node, position: node.position)
                    }
                } else {
                    setPosition(node, position: node.position)
                }
            default:
                ()
            }
        }
    }
    
}
