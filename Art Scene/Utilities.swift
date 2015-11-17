//
//  Utilities.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/21/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

enum Units {
    case Inches
    case Feet
}

enum NodeEdge {
    case None
    case Top
    case Bottom
    case Left
    case Right
    case Pivot
}

enum NodeType: String {
    case Wall
    case Frame
    case Top
    case Bottom
    case Left
    case Right
    case Matt
    case Picture
    case Image
    case Floor
}

enum EditMode {
    case None
    case Resizing(NodeType, NodeEdge)
    case Moving(NodeType)
    case Selecting
    case ContextualMenu
    case GetInfo
}

enum Axis {
    case X
    case Y
}

func hitOfType(hits: [SCNHitTestResult], type: NodeType) -> SCNHitTestResult?
{
    let key = type.rawValue
    let found = hits.filter { $0.node.name == key }
    if found.isEmpty {
        return nil
    } else {
        return found[0]
    }
}

func nodeType (node: SCNNode?) -> NodeType?
{
    if  let node = node,
        let name = node.name {
        return NodeType(rawValue: name)
    } else {
        return nil
    }
}

func parent(node: SCNNode, ofType type: NodeType) -> SCNNode?
{
    var tmp: SCNNode? = node
    repeat {
        tmp = tmp?.parentNode
    } while tmp != nil && nodeType(tmp) != type
    return tmp
}

func runOpenPanel() -> NSURL?
{
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.resolvesAliases = true
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = NSImage.imageTypes()
    let button = panel.runModal()
    if button == NSFileHandlingPanelOKButton {
        return panel.URL!
    } else {
        return nil
    }
}

let r2d = CGFloat(180.0 / M_PI)

//func roundToQuarterInch(x: CGFloat) -> CGFloat
//{
//    let quarters = round(x * 12 * 4)
//    return quarters / (12 * 4)
//}

//func constrainToGrid(point: SCNVector3) -> SCNVector3
//{
//    
//    return SCNVector3(x: roundToQuarterInch(point.x), y: roundToQuarterInch(point.y), z: point.z)
//}

func nodeSize(node: SCNNode) -> CGSize
{
    if let plane = node.geometry as? SCNPlane {
        return CGSize(width: plane.width, height: plane.height)
    } else {
        return CGSize.zero
    }
}

func setNodeEmission(parentNode: SCNNode, color: NSColor) {
    let children = parentNode.childNodesPassingTest {  x, yes in x.geometry != nil }
    
    for child in children {
        let material = child.geometry!.firstMaterial!
        material.emission.contents = color
    }
    
}

/// Return the positive distance from the left edge of the picture's wall. (The picture's position
/// is in a coordinate system with {0, 0} at the center of the wall.
func distanceForPicture(node: SCNNode, axis: Axis, coordinate: CGFloat = 0.0) -> String
{
    let wallSize = nodeSize(node.parentNode!)
    let distance: CGFloat = {
        switch axis {
        case .X:
            return coordinate + wallSize.width / 2.0
        case .Y:
            return coordinate + wallSize.height / 2.0
        }}()
    return convertToFeetAndInches(distance, units: .Feet)
}

/// GetInfo properties for a wall.
func wallInfo(wall: SCNNode, camera: SCNNode? = nil) -> (size: String, location: String, rotation: String, distance: String?) {
    let plane = wall.geometry as! SCNPlane
    let length = convertToFeetAndInches(plane.width)
    let height = convertToFeetAndInches(plane.height)
    let x = convertToFeetAndInches(wall.position.x)
    let y = convertToFeetAndInches(wall.position.z)
    let angle = (wall.eulerAngles.y * r2d) % 360.0
    let rotation = String(format: "%0.0f°", angle)
    var distance: String? = nil
    if let camera = camera {
        let x = wall.position.x - camera.position.x
        let z = wall.position.z - camera.position.z
        distance =  convertToFeetAndInches(sqrt(x * x + z * z))
    }
    return (length + " x " + height, x + ", " + y, rotation, distance)

}

/// GetInfo properties for a picture.
func pictureInfo(node: SCNNode) -> (size: String, location: String, name: String?) {
    let plane = node.geometry as! SCNPlane
    let s = plane.name as NSString?
    let name: NSString? = s?.lastPathComponent
    let size = nodeSize(node)
    let wall = node.parentNode!
    let area = wall.geometry as! SCNPlane
    return ("\(convertToFeetAndInches(size.width, units: .Inches)) x \(convertToFeetAndInches(size.height, units: .Inches))",
            "\(convertToFeetAndInches(node.position.x + area.width / 2)), \(convertToFeetAndInches(node.position.y + area.height / 2))",
            name as String?)
}

/// Determine if a wall with `newSize` contains all its pictures.
func wallContainsPictures(wall: SCNNode, withNewSize newSize: CGSize) -> Bool
{
    let pictures = wall.childNodesPassingTest( { x, yes in x.name == "Picture"} )
    if pictures.isEmpty {
        return true
    } else {
        let rect = CGRect(x: -newSize.width / 2, y: -newSize.height / 2, width: newSize.width, height: newSize.height)
        for picture in pictures {
            let frame = picture.geometry as! SCNPlane
            let r = CGRect(x: picture.position.x - frame.width / 2, y: picture.position.y - frame.height / 2,
                width: frame.width, height: frame.height)
            if !CGRectContainsRect(rect, r) {
                return false
            }
        }
        return true
    }
}

func convertToFeetAndInches(length: CGFloat, units:Units = .Feet) -> String
{
    
    let xFeet = units == .Feet ? Int(length) : 0
    let xInches: CGFloat = {
        let x = (length - CGFloat(xFeet)) * 12.0
        return xFeet == 0 ? x : abs(x)
        }()
    let quarterInches = round(xInches * 4)
    let wholeInches = floor(quarterInches / 4)
    let fractionalInches = xInches - wholeInches
    var formattedFractionalInches = ""
    switch round(fractionalInches / 0.25) {
    case 0:
        if wholeInches > 0 {
            formattedFractionalInches = "'"
        }
    case 1:
        formattedFractionalInches = "¼\""
    case 2:
        formattedFractionalInches = "½\""
    case 3:
        formattedFractionalInches = "¾\""
    default:
        break
    }
    let formattedFeet = xFeet == 0 ? "" : "\(xFeet)'"
    let formattedInches = wholeInches == 0 ? "" : "\(Int(wholeInches))"
    return formattedFeet + formattedInches + formattedFractionalInches
}

/// 
func makeThumbnail(picture: SCNNode) -> (String, NSImage)? {
    let geometry = picture.geometry!
    if let name: String = geometry.name,
        let original = NSImage(byReferencingFile: name),
        let imageNode = picture.childNodeWithName("Image", recursively: true),
        let imageSize = imageNode.geometry as? SCNPlane {
            let thumbnail = NSImage(size: NSSize(width: imageSize.width * 100, height: imageSize.height * 100))
            thumbnail.lockFocus()
            let toRect = NSRect(x: 0, y: 0, width: thumbnail.size.width, height: thumbnail.size.height)
            original.drawInRect(toRect, fromRect: NSRect(origin: CGPoint.zero, size: original.size), operation: NSCompositingOperation.CompositeCopy, fraction: 1.0, respectFlipped: false, hints: nil)
            thumbnail.unlockFocus()
            return (name, thumbnail)
    }
    return nil
}


func crossProduct(a: SCNVector3, b: SCNVector3) -> SCNVector3
{
    return SCNVector3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
}

func moveNode(deltaUp: CGFloat, deltaRight: CGFloat, node: SCNNode)
{
    let angle = node.eulerAngles.y
    let v = SCNVector3(x: sin(angle), y: 0.0, z: cos(angle))
//    let u = crossProduct(v, b: SCNVector3(0, 1, 0))
    let u = v × SCNVector3(0, 1, 0)
    node.position.x += v.x * deltaUp + u.x * deltaRight
    node.position.z += v.z * deltaUp + u.z * deltaRight
}