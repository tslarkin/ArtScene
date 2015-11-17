//
//  SCNVector Extensions.swift
//  Art Scene
//
//  Created by Timothy Larkin on 11/15/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import SceneKit

func + (u: SCNVector3, v: SCNVector3) -> SCNVector3 {
    return SCNVector3(x: u.x + v.x, y: u.y + v.y, z: u.z + v.z)
}

func - (u: SCNVector3, v: SCNVector3) -> SCNVector3 {
    return SCNVector3(x: u.x - v.x, y: u.y - v.y, z: u.z - v.z)
}

func == (u: SCNVector3, v: SCNVector3) -> Bool {
    return u.x == v.x && u.y == v.y && u.z == v.z
}

func != (u: SCNVector3, v: SCNVector3) -> Bool {
    return !(u == v)
}

infix operator × { associativity left precedence 100 }

func × (a: SCNVector3, b: SCNVector3) -> SCNVector3
{
    return SCNVector3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)    
}