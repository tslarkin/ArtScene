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
        }
    }
    
    @objc func setChildNodes(_ nodes: [SCNNode]) {
        for node in childNodes {
            node.removeFromParentNode()
        }
        for node in nodes {
            addChildNode(node)
        }
    }
    
    @objc func replaceChildNode(_ args:[SCNNode])
    {
        replaceChildNode(args[0], with: args[1])
    }
    
    @objc func setCoordinates(_ newPosition: [CGFloat])
    {
        position = SCNVector3Make(newPosition[0], newPosition[1], newPosition[2])
    }
    
    func yRotation()->CGFloat {
        return eulerAngles.y
    }
    
    @objc func setYRotation(_ y: CGFloat) {
        eulerAngles.y = y
    }
}
