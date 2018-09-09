//
//  Utilities.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/21/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

let minimumPictureSize: CGFloat = 1.0 / 3.0
let minimumImageSize: CGFloat = 1.0 / 6.0
enum Units {
    case inches
    case feet
}

indirect enum NodeEdge: Equatable {
    case none
    case top
    case bottom
    case left
    case right
    case pivot
    case side(Int, NodeEdge)
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
    case Back
    case Grid
    case Box
}

enum EditMode {
    case none
    case resizing(NodeType, NodeEdge)
    case moving(NodeType)
    case selecting
    case contextualMenu
    case getInfo
}

enum Axis {
    case x
    case y
}

func hitOfType(_ hits: [SCNHitTestResult], type: NodeType) -> SCNHitTestResult?
{
    let key = type.rawValue
    let found = hits.filter { $0.node.name == key }
    if found.isEmpty {
        return nil
    } else {
        return found[0]
    }
}

func nodeType (_ node: SCNNode?) -> NodeType?
{
    if  let node = node,
        let name = node.name {
        return NodeType(rawValue: name)
    } else {
        return nil
    }
}

func parent(_ node: SCNNode, ofType type: NodeType) -> SCNNode?
{
    var tmp: SCNNode? = node
    while tmp != nil && nodeType(tmp) != type {
        tmp = tmp?.parent
    }
    return tmp
}

func pictureOf(_ node: SCNNode)->SCNNode? {
    return parent(node, ofType: .Picture)
}

func theImage(_ node: SCNNode)->SCNNode
{
    return node.childNode(withName: "Image", recursively: false)!
}

func theMatt(_ node: SCNNode)->SCNNode
{
    return node.childNode(withName: "Matt", recursively: false)!
}

func theFrame(_ node: SCNNode)->SCNNode
{
    return node.childNode(withName: "Frame", recursively: false)!
}

func thePlane(_ node: SCNNode)->SCNPlane
{
    return node.geometry as! SCNPlane
}

func theGeometry(_ node: SCNNode)->SCNGeometry
{
    return node.geometry!
}

func runOpenPanel() -> URL?
{
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.resolvesAliases = true
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = NSImage.imageTypes
    let button = panel.runModal()
    if button == NSApplication.ModalResponse.OK {
        return panel.url!
    } else {
        return nil
    }
}

let r2d = CGFloat(180.0 / .pi)

func nodeSize(_ node: SCNNode) -> CGSize
{
    if let plane = node.geometry as? SCNPlane {
        return CGSize(width: plane.width, height: plane.height)
    } else {
        return CGSize.zero
    }
}

func setNodeEmission(_ parentNode: SCNNode, color: NSColor) {
    let children = parentNode.childNodes {  x, yes in x.geometry != nil }
    
    for child in children {
        let material = child.geometry!.firstMaterial!
        material.emission.contents = color
    }
    
}

/// Return the positive distance from the left edge of the picture's wall. (The picture's position
/// is in a coordinate system with {0, 0} at the center of the wall.
func distanceForPicture(_ node: SCNNode, axis: Axis, coordinate: CGFloat = 0.0) -> String
{
    let wallSize = nodeSize(node.parent!)
    let distance: CGFloat = {
        switch axis {
        case .x:
            return coordinate + wallSize.width / 2.0
        case .y:
            return coordinate + wallSize.height / 2.0
        }}()
    return convertToFeetAndInches(distance, units: .feet)
}

/// GetInfo properties for a wall.

func wallInfo(_ wall: SCNNode, camera: SCNNode? = nil, hitPosition: SCNVector3? = nil) -> (x: String, y: String, width: String, height: String, rotation: String, distance: String?) {
    let plane = wall.geometry as! SCNPlane
    let length = convertToFeetAndInches(plane.width)
    let height = convertToFeetAndInches(plane.height)
    let x = convertToFeetAndInches(wall.position.x)
    let y = convertToFeetAndInches(-wall.position.z)
    var angle = (wall.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
    if angle < 0 {
        angle += 360.0
    }
    let rotation = String(format: "%0.0f°", angle)
    var distance: String? = nil
    if let camera = camera {
        let position = hitPosition != nil ? hitPosition! : wall.position
        let x = position.x - camera.position.x
        let z = position.z - camera.position.z
        distance =  convertToFeetAndInches(sqrt(x * x + z * z))
    }
    return (x, y, length, height, rotation, distance)
    
}

func boxInfo(_ boxNode: SCNNode)->(x: String, y: String, width: String, height: String, length: String, rotation: String) {
    let box = boxNode.geometry as! SCNBox
    let width = convertToFeetAndInches(box.width)
    let length = convertToFeetAndInches(box.length)
    let height = convertToFeetAndInches(box.height)
    let x = convertToFeetAndInches(boxNode.position.x)
    let y = convertToFeetAndInches(-boxNode.position.z)
    var angle = (boxNode.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
    if angle < 0 {
        angle += 360.0
    }
    let rotation = String(format: "%0.0f°", angle)
    return (x, y, width, height, length, rotation)
}

/// GetInfo properties for a picture.
func pictureInfo(_ node: SCNNode, camera: SCNNode? = nil, hitPosition: SCNVector3? = nil) -> (x: String, y: String, width: String, height: String, hidden: String, distance: String) {
    let size = nodeSize(node)
    let wall = node.parent!
    let area = wall.geometry as! SCNPlane
    var distance = ""
    if camera != nil && hitPosition != nil {
        let x = hitPosition!.x - camera!.position.x
        let z = hitPosition!.z - camera!.position.z
        distance =  convertToFeetAndInches(sqrt(x * x + z * z))
    }
    return (convertToFeetAndInches(node.position.x + area.width / 2),
        convertToFeetAndInches(node.position.y + area.height / 2),convertToFeetAndInches(size.width, units: .inches),
        convertToFeetAndInches(size.height, units: .inches),
        theFrame(node).isHidden ? "No" : "Yes", distance)
}


/// GetInfo properties for an image.
func imageInfo(_ node: SCNNode) -> (width: String, height: String, name: String) {
    // The node might be the picture or the image itself
    let type = nodeType(node)
    let plane = type == .Image ? thePlane(pictureOf(node)!) : thePlane(node)
    let s = plane.name! as NSString
    let name = (s.lastPathComponent as NSString).deletingPathExtension
    let size = type == .Image ? node.size()! : theImage(node).size()!
    return (convertToFeetAndInches(size.width, units: .inches),
        convertToFeetAndInches(size.height, units: .inches),
        name)
}

func convertToFeetAndInches(_ length: CGFloat, units:Units = .feet) -> String
{
    if abs(length) < 0.01 {
        return "0\'"
    }
    let xFeet = units == .feet ? Int(length) : 0
    var xInches: CGFloat = (length - CGFloat(xFeet)) * 12.0
    if xFeet != 0 { xInches = abs(xInches) }
    let wholeInches = floor(xInches)
    let fractionalInches = xInches - wholeInches
    var formattedFractionalInches = ""
    switch Int(fractionalInches / 0.25) {
    case 0:
        if abs(wholeInches) > 0 {
            formattedFractionalInches = "\""
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
    let formattedInches = wholeInches == 0 ? "" : String(format:"%d", Int(wholeInches))
    let formattedFeet = (units == Units.inches || xFeet == 0 && (wholeInches != 0.0 || fractionalInches != 0.0)) ? "" : String(format: "%d'", xFeet)
    return formattedFeet + formattedInches + formattedFractionalInches
}

/// 
func makeThumbnail(_ picture: SCNNode) -> (String, NSImage)? {
    let geometry = picture.geometry!
    if let name: String = geometry.name,
        let original = NSImage(byReferencingFile: name) {
        let imageNode = theImage(picture)
        let plane = thePlane(imageNode)
        let thumbnail = NSImage(size: NSSize(width: plane.width * 100, height: plane.height * 100))
        thumbnail.lockFocus()
        let toRect = NSRect(x: 0, y: 0, width: thumbnail.size.width, height: thumbnail.size.height)
        original.draw(in: toRect, from: NSRect(origin: CGPoint.zero, size: original.size), operation: NSCompositingOperation.copy, fraction: 1.0, respectFlipped: false, hints: nil)
        thumbnail.unlockFocus()
        return (name, thumbnail)
    }
    return nil
}


func crossProduct(_ a: SCNVector3, b: SCNVector3) -> SCNVector3
{
    return SCNVector3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
}

func newPositionFromAngle(_ oldPosition: SCNVector3, deltaAway: CGFloat, deltaRight: CGFloat, angle: CGFloat)->SCNVector3
{
    var newPosition = oldPosition
    let v = SCNVector3(x: sin(angle), y: 0.0, z: cos(angle))
    //    let u = crossProduct(v, b: SCNVector3(0, 1, 0))
    let u = v × SCNVector3(0, 1, 0)
    newPosition.x += v.x * deltaAway + u.x * deltaRight
    newPosition.z += v.z * deltaAway + u.z * deltaRight
    return newPosition
}

func primeFactors(_ numToCheck:Int) -> [(factor: Int, power: Int)] {
    
    if numToCheck == 1 { return []}
    
    var primeFactors:Array<(Int, Int)> = []
    var n = numToCheck
    let divisor = 2
    var count: Int = 0
    while n >= divisor && n % divisor == 0 {
        count += 1
        n = n / 2
    }
    if count > 0 {
        primeFactors.append((divisor, count))
    }
    for divisor in stride(from: 3, to: Int(Double(n).squareRoot()) + 1, by:2) {
        count = 0
        while n >= divisor && n % divisor == 0 {
            count += 1
            n = n / divisor
        }
        if count > 0 {
            primeFactors.append((divisor, count))
        }
    }
    if n > 1 {
        primeFactors.append((n, 1))
    }
    return primeFactors
}

func isPrime(_ num: Int)->Bool {
    let factors = primeFactors(num)
    return factors.count == 1 && factors[0].power == 1
}

var snapToGridP = true
let gridFactor:CGFloat = 48.0
let rotationFactor: CGFloat = 1.0 / (.pi / 180.0 * 5)

func snapToGrid(_ position: SCNVector3)->SCNVector3 {
    if !snapToGridP {
        return position
    }
    var p = position
    p.x = round(position.x * gridFactor) / gridFactor
    p.y = round(position.y * gridFactor) / gridFactor
    p.z = round(position.z * gridFactor) / gridFactor
    return p
}

func snapToGrid(_ size: CGSize)->CGSize {
    if !snapToGridP {
        return size
    }
    var s = size
    s.height = round(size.height * gridFactor) / gridFactor
    s.width = round(size.width * gridFactor) / gridFactor
    return s
}

func snapToGrid(_ angle: CGFloat)->CGFloat{
    if !snapToGridP {
        return angle
    }
    var degrees = angle * r2d
    degrees = round(degrees / rotationFactor) * rotationFactor
    return degrees / r2d
}

func makeGrid(size: CGSize, spacing: CGFloat)->SCNNode
{
    let hCount: Int = Int(ceil(size.height / spacing)) // number of horizontal lines
    let vCount: Int = Int(ceil(size.width / spacing)) + 1 // number of vertical lines
    let indices: [Int32] = (0...((hCount + vCount) * 2)).map({ Int32($0) })
    var vectors: [SCNVector3] = []
    var y = -size.height / 2.0
    for _ in 0...hCount {
        let vector1 = SCNVector3Make(-size.width / 2.0, y, 0.0)
        let vector2 = SCNVector3Make(size.width / 2.0, y, 0.0)
        vectors.append(vector1)
        vectors.append(vector2)
        y += spacing
    }
    var x = -size.width / 2.0
    for _ in 0...vCount {
        let vector1 = SCNVector3Make(x, -size.height / 2.0, 0.0)
        let vector2 = SCNVector3Make(x, size.height / 2.0, 0.0)
        vectors.append(vector1)
        vectors.append(vector2)
        x += spacing
    }
    
    let source = SCNGeometrySource(vertices: vectors)
    let element = SCNGeometryElement(indices: indices, primitiveType: .line)
    
    let shape = SCNGeometry(sources: [source], elements: [element])
    let gridColor = NSColor.black //(calibratedRed: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
    let material = SCNMaterial()
    material.diffuse.contents = gridColor
    shape.materials = [material]
    let grid = SCNNode(geometry: shape)
    
    grid.name = "Grid"
    grid.position = SCNVector3Make(0.0, 0.0, 0.001)
    return grid
}
