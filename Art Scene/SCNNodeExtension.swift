//
//  SCNNodeExtension.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/17/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit

extension SCNNode
{
    
    func size()->CGSize?
    {
        if let geometry = geometry as? SCNPlane {
            return CGSize(width: geometry.width, height: geometry.height)
        }
        return nil
    }
    
    @objc func setSize(_ size: CGSize)
    {
        if let geometry = geometry as? SCNPlane {
            geometry.width = size.width
            geometry.height = size.height
            if hasGrid() {
                setGrid()
            }
        }
    }
    
    var leftEdge: CGFloat {
        var x = size()!.width / 2.0
        if nodeType(self) == .Picture && theFrame(self).isHidden {
            x = theImage(self).size()!.width / 2.0
        }
        return position.x - x
    }
    
    var bottomEdge: CGFloat {
        var y = size()!.height / 2.0
        if nodeType(self) == .Picture && theFrame(self).isHidden {
            y = theImage(self).size()!.height / 2.0
        }
        return position.y - y
    }
    
    var topEdge: CGFloat {
        var y = size()!.height / 2.0
        if nodeType(self) == .Picture && theFrame(self).isHidden {
            y = theImage(self).size()!.height / 2.0
        }
        return position.y + y
    }
    
    var centerX: CGFloat {
        return position.x
    }
    
    var centerY: CGFloat {
        return position.y
    }
    
    var yRotation: CGFloat {
        get {
            return eulerAngles.y
        }
        set {
            eulerAngles.y = newValue
        }
    }
    
    func setGrid()
    {
        if hasGrid() {
            removeGrid()
        }
        let gap = 1.0 / gridFactor * 4.0
        let mySize = size()!
        let hCount: Int = Int(ceil(mySize.height / gap)) // number of horizontal lines
        let vCount: Int = Int(ceil(mySize.width / gap)) + 1 // number of vertical lines
        let hFootCount: Int = hCount / 12
        let vFootCount: Int = vCount / 12 + 1
        let inchIndices: [Int32] = (0...((hCount + vCount - (hFootCount + vFootCount)) * 2)).map({ Int32($0) })
        let footIndices: [Int32] = (0...((hFootCount + vFootCount) * 2)).map({ Int32($0) })
        var inchGrid: [SCNVector3] = []
        var footGrid: [SCNVector3] = []
        var y = -mySize.height / 2.0
        for line in 0...hCount {
            let vector1 = SCNVector3Make(-mySize.width / 2.0, y, 0.0)
            let vector2 = SCNVector3Make(mySize.width / 2.0, y, 0.0)
            if line % 12 == 0 {
                footGrid.append(vector1)
                footGrid.append(vector2)
            } else {
                inchGrid.append(vector1)
                inchGrid.append(vector2)
            }
            y += gap
        }
        var x = -mySize.width / 2.0
        for line in 0...vCount {
            let vector1 = SCNVector3Make(x, -mySize.height / 2.0, 0.0)
            let vector2 = SCNVector3Make(x, mySize.height / 2.0, 0.0)
            if line % 12 == 0 {
                footGrid.append(vector1)
                footGrid.append(vector2)
            } else {
                inchGrid.append(vector1)
                inchGrid.append(vector2)
            }
            x += gap
        }

        var source = SCNGeometrySource(vertices: inchGrid)
        var element = SCNGeometryElement(indices: inchIndices, primitiveType: .line)
        
        var shape = SCNGeometry(sources: [source], elements: [element])
        var gridColor = NSColor(calibratedRed: 0.05, green: 0.5, blue: 1.0, alpha: 0.98)
        var material = SCNMaterial()
        material.emission.contents = gridColor
        shape.materials = [material]
        let inches = SCNNode(geometry: shape)
 
        source = SCNGeometrySource(vertices: footGrid)
        element = SCNGeometryElement(indices: footIndices, primitiveType: .line)
        
        shape = SCNGeometry(sources: [source], elements: [element])
        gridColor = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        material = SCNMaterial()
        material.emission.contents = gridColor
        shape.materials = [material]
        let feet = SCNNode(geometry: shape)

        let grid = SCNNode()
        grid.addChildNode(inches)
        grid.addChildNode(feet)
        grid.name = "Grid"
        grid.position = SCNVector3Make(0.0, 0.0, 0.001)
        addChildNode(grid)
    }
    
    func grid()->SCNNode?
    {
        return childNode(withName: "Grid", recursively: false)
    }
    
    func hasGrid()->Bool
    {
        return grid() != nil
    }
    
    func removeGrid()
    {
        if let grid = childNode(withName: "Grid", recursively: false) {
            grid.removeFromParentNode()
        }
    }
    
}
