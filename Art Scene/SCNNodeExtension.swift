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
    
}
