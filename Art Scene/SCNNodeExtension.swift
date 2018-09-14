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
        return position.x - size()!.width / 2.0
    }
    
    var bottomEdge: CGFloat {
        return position.y - size()!.height / 2.0
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
        let indices: [Int32] = (0...((hCount + vCount) * 2)).map({ Int32($0) })
        var vectors: [SCNVector3] = []
        var y = -mySize.height / 2.0
        for _ in 0...hCount {
            let vector1 = SCNVector3Make(-mySize.width / 2.0, y, 0.0)
            let vector2 = SCNVector3Make(mySize.width / 2.0, y, 0.0)
            vectors.append(vector1)
            vectors.append(vector2)
            y += gap
        }
        var x = -mySize.width / 2.0
        for _ in 0...vCount {
            let vector1 = SCNVector3Make(x, -mySize.height / 2.0, 0.0)
            let vector2 = SCNVector3Make(x, mySize.height / 2.0, 0.0)
            vectors.append(vector1)
            vectors.append(vector2)
            x += gap
        }

        let source = SCNGeometrySource(vertices: vectors)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let shape = SCNGeometry(sources: [source], elements: [element])
        let gridColor = NSColor(calibratedRed: 0.05, green: 0.5, blue: 1.0, alpha: 0.98)
        let material = SCNMaterial()
        material.emission.contents = gridColor
        shape.materials = [material]
        let grid = SCNNode(geometry: shape)
        
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
