//: Playground - noun: a place where people can play

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

infix operator × //{ associativity left precedence 100 }

func × (a: SCNVector3, b: SCNVector3) -> SCNVector3
{
    return SCNVector3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
}

infix operator •
func • (a: SCNVector3, b: SCNVector3)->CGFloat
{
    return a.x * b.x + a.y * b.y + a.z * b.z
}

func *(a: CGFloat, b: SCNVector3)->SCNVector3
{
    return SCNVector3Make(a * b.x, a * b.y, a * b.z)
}

let d = SCNVector3Make(1, 3, -5) • SCNVector3Make(4, -2, -1)


let theta: CGFloat = -.pi / 2.0

// https://stackoverflow.com/questions/45966373/rotate-scnvector3-around-an-axis
// Rodrigues' rotation formula.
let v = SCNVector3Make(1, 0, 2)
let k = SCNVector3Make(0, 1, 0)
let vr1 = (cos(theta) * v)
let vr2 = (sin(theta) * (k × v))
let vr3 = (1 - cos(theta)) * ((k • v) * k )
let vr =  vr1 - vr2 + vr3
tan(.pi / 2.0 * 1.000000000000001)
